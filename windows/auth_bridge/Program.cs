using System.Globalization;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace FindDoctorAuthBridge;

internal static class Program
{
    private const int MaximumFailedAttempts = 5;
    private static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);
    private static readonly string DummyHash = PasswordHasher.Hash(Guid.NewGuid().ToString("N"));

    private static async Task Main()
    {
        try
        {
            var input = await Console.In.ReadLineAsync();
            if (string.IsNullOrWhiteSpace(input) || input.Length > 16_384)
            {
                Write(new { status = "invalid_request" });
                return;
            }

            var request = JsonSerializer.Deserialize<LoginRequest>(
                input,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (request is null || request.Operation != "login")
            {
                Write(new { status = "invalid_request" });
                return;
            }

            var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;
            var password = request.Password ?? string.Empty;
            if (!MailAddress.TryCreate(email, out var address) ||
                !string.Equals(address.Address, email, StringComparison.Ordinal) ||
                password.Length is < 1 or > 1024)
            {
                PasswordHasher.Verify(password, DummyHash);
                Write(new { status = "invalid_credentials" });
                return;
            }

            var databasePath = FindDatabasePath();
            if (databasePath is null)
            {
                Write(new { status = "store_unavailable" });
                return;
            }

            Authenticate(databasePath, email, password);
        }
        catch (SqliteException)
        {
            Write(new { status = "store_unavailable" });
        }
        catch (Exception)
        {
            Write(new { status = "service_unavailable" });
        }
    }

    private static void Authenticate(string databasePath, string email, string password)
    {
        using var connection = new SqliteConnection(
            new SqliteConnectionStringBuilder
            {
                DataSource = databasePath,
                Mode = SqliteOpenMode.ReadWrite,
                Cache = SqliteCacheMode.Private,
                Pooling = false
            }.ToString());
        connection.Open();

        using var transaction = connection.BeginTransaction();
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            SELECT FullName, Email, Role, IsVerified, PasswordHash,
                   FailedLoginAttempts, LockoutUntilUtc, HospitalName, MedicalSpecialty
            FROM Users
            WHERE lower(trim(Email)) = $email
            LIMIT 2;
            """;
        command.Parameters.AddWithValue("$email", email);

        using var reader = command.ExecuteReader();
        if (!reader.Read())
        {
            reader.Close();
            PasswordHasher.Verify(password, DummyHash);
            transaction.Commit();
            Write(new { status = "invalid_credentials" });
            return;
        }

        var user = new StoredUser(
            FullName: reader.IsDBNull(0) ? string.Empty : reader.GetString(0),
            Email: reader.IsDBNull(1) ? email : reader.GetString(1),
            Role: reader.IsDBNull(2) ? string.Empty : reader.GetString(2),
            IsVerified: ReadBoolean(reader.GetValue(3)),
            PasswordHash: reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
            FailedLoginAttempts: reader.IsDBNull(5) ? 0 : Convert.ToInt32(reader.GetValue(5), CultureInfo.InvariantCulture),
            LockoutUntilUtc: reader.IsDBNull(6) ? null : reader.GetValue(6)?.ToString(),
            HospitalName: reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
            MedicalSpecialty: reader.IsDBNull(8) ? string.Empty : reader.GetString(8));
        var duplicate = reader.Read();
        reader.Close();

        if (duplicate)
        {
            PasswordHasher.Verify(password, DummyHash);
            transaction.Commit();
            Write(new { status = "invalid_credentials" });
            return;
        }

        if (TryReadUtc(user.LockoutUntilUtc, out var lockoutUntil) && lockoutUntil > DateTime.UtcNow)
        {
            transaction.Commit();
            Write(new { status = "locked" });
            return;
        }

        var role = NormalizeRole(user.Role);
        var supportedRole = role is "Patient" or "Student" or "Doctor" or "Manager" or "Doctor Manager" or "General Manager";
        var requiresApproval = role is "Doctor" or "Manager" or "Doctor Manager" or "General Manager";
        var verified = PasswordHasher.Verify(password, user.PasswordHash);

        if (!supportedRole || (requiresApproval && !user.IsVerified) || string.IsNullOrEmpty(user.PasswordHash))
        {
            transaction.Commit();
            Write(new { status = "invalid_credentials" });
            return;
        }

        if (!verified)
        {
            var failedAttempts = user.FailedLoginAttempts + 1;
            var shouldLock = failedAttempts >= MaximumFailedAttempts;
            using var update = connection.CreateCommand();
            update.Transaction = transaction;
            update.CommandText = """
                UPDATE Users
                SET FailedLoginAttempts = $attempts,
                    LockoutUntilUtc = $lockout
                WHERE lower(trim(Email)) = $email;
                """;
            update.Parameters.AddWithValue("$attempts", shouldLock ? 0 : failedAttempts);
            update.Parameters.AddWithValue("$lockout", shouldLock
                ? DateTime.UtcNow.Add(LockoutDuration).ToString("O", CultureInfo.InvariantCulture)
                : DBNull.Value);
            update.Parameters.AddWithValue("$email", email);
            update.ExecuteNonQuery();
            transaction.Commit();
            Write(new { status = shouldLock ? "locked" : "invalid_credentials" });
            return;
        }

        using (var update = connection.CreateCommand())
        {
            update.Transaction = transaction;
            update.CommandText = """
                UPDATE Users
                SET FailedLoginAttempts = 0, LockoutUntilUtc = NULL
                WHERE lower(trim(Email)) = $email;
                """;
            update.Parameters.AddWithValue("$email", email);
            update.ExecuteNonQuery();
        }

        transaction.Commit();
        Write(new
        {
            status = "success",
            user = new
            {
                fullName = user.FullName,
                email = user.Email,
                role,
                isVerified = user.IsVerified,
                hospitalName = user.HospitalName,
                specialty = user.MedicalSpecialty
            }
        });
    }

    private static string? FindDatabasePath()
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FindDoctorApp", "finddoctor.db"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "FindDoctor", "finddoctor.db"),
            Path.Combine(AppContext.BaseDirectory, "finddoctor.db"),
            Path.Combine(Environment.CurrentDirectory, "finddoctor.db")
        };

        return candidates.FirstOrDefault(File.Exists);
    }

    private static string NormalizeRole(string value)
    {
        var role = value.Trim();
        if (role.Equals("patient", StringComparison.OrdinalIgnoreCase)) return "Patient";
        if (role.Equals("student", StringComparison.OrdinalIgnoreCase)) return "Student";
        if (role.Equals("doctor", StringComparison.OrdinalIgnoreCase)) return "Doctor";
        if (role.Equals("manager", StringComparison.OrdinalIgnoreCase)) return "Manager";
        if (role.Equals("doctor manager", StringComparison.OrdinalIgnoreCase)) return "Doctor Manager";
        if (role.Equals("general manager", StringComparison.OrdinalIgnoreCase)) return "General Manager";
        return string.Empty;
    }

    private static bool ReadBoolean(object value) => value switch
    {
        long number => number != 0,
        int number => number != 0,
        bool boolean => boolean,
        string text => text.Equals("true", StringComparison.OrdinalIgnoreCase) || text == "1",
        _ => false
    };

    private static bool TryReadUtc(string? value, out DateTime result)
    {
        if (DateTime.TryParse(value, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out result))
            return true;
        result = default;
        return false;
    }

    private static void Write(object result) => Console.Out.WriteLine(JsonSerializer.Serialize(result));

    private sealed record LoginRequest(string? Operation, string? Email, string? Password);
    private sealed record StoredUser(
        string FullName,
        string Email,
        string Role,
        bool IsVerified,
        string PasswordHash,
        int FailedLoginAttempts,
        string? LockoutUntilUtc,
        string HospitalName,
        string MedicalSpecialty);

    private static class PasswordHasher
    {
        private const int HashSize = 32;

        public static string Hash(string password)
        {
            var salt = RandomNumberGenerator.GetBytes(16);
            var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, 600_000, HashAlgorithmName.SHA256, HashSize);
            return $"pbkdf2-sha256$600000${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
        }

        public static bool Verify(string password, string encoded)
        {
            var parts = encoded.Split('$');
            if (parts.Length != 4 || parts[0] != "pbkdf2-sha256" ||
                !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var iterations) ||
                iterations is < 100_000 or > 2_000_000)
                return false;

            try
            {
                var salt = Convert.FromBase64String(parts[2]);
                var expected = Convert.FromBase64String(parts[3]);
                if (salt.Length < 16 || expected.Length != HashSize) return false;
                var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
                return CryptographicOperations.FixedTimeEquals(actual, expected);
            }
            catch (FormatException)
            {
                return false;
            }
        }
    }
}
