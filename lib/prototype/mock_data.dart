class MockDoctor {
  const MockDoctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.hospitalType,
    required this.rating,
    required this.consultations,
    required this.operations,
    required this.priceRm,
    required this.available,
    required this.verified,
    required this.initials,
    required this.bio,
    this.yearsExperience = 10,
    this.photoAsset,
  });

  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final String hospitalType;
  final double rating;
  final int consultations;
  final int operations;
  final int priceRm;
  final bool available;
  final bool verified;
  final String initials;
  final String bio;
  final int yearsExperience;
  final String? photoAsset;
}

class MockPatient {
  const MockPatient({
    required this.id,
    required this.name,
    required this.birthday,
    required this.city,
    required this.initials,
  });

  final String id;
  final String name;
  final String birthday;
  final String city;
  final String initials;
}

class MockManager {
  const MockManager({
    required this.id,
    required this.name,
    required this.level,
    required this.hospital,
    required this.initials,
  });

  final String id;
  final String name;
  final String level;
  final String hospital;
  final String initials;
}

class MockPost {
  const MockPost({
    required this.id,
    required this.author,
    required this.role,
    required this.workplace,
    required this.date,
    required this.content,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.mediaLabel,
    required this.initials,
  });

  final String id;
  final String author;
  final String role;
  final String workplace;
  final String date;
  final String content;
  final int likes;
  final int comments;
  final int shares;
  final String mediaLabel;
  final String initials;
}

class MockChat {
  const MockChat({
    required this.id,
    required this.title,
    required this.preview,
    required this.time,
    required this.type,
    required this.unread,
  });

  final String id;
  final String title;
  final String preview;
  final String time;
  final String type;
  final int unread;
}

class MockApplication {
  const MockApplication({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.hospital,
    required this.submitted,
    required this.status,
  });

  final String id;
  final String doctorName;
  final String specialty;
  final String hospital;
  final String submitted;
  final String status;
}

class MockData {
  static const doctors = [
    MockDoctor(
      id: 'd1',
      name: 'Dr. Emily Chen',
      specialty: 'Cardiology',
      hospital: 'Metropolitan Heart Institute',
      hospitalType: 'Private',
      rating: 4.9,
      consultations: 1280,
      operations: 210,
      priceRm: 180,
      available: true,
      verified: true,
      initials: 'AR',
      bio:
          'Consultant cardiologist focusing on preventive care and interventional procedures.',
      yearsExperience: 15,
      photoAsset: 'assets/images/doctor_emily_chen.png',
    ),
    MockDoctor(
      id: 'd2',
      name: 'Dr. Wei Jun Tan',
      specialty: 'Orthopaedics',
      hospital: 'Gleneagles Hospital Penang',
      hospitalType: 'Private',
      rating: 4.7,
      consultations: 940,
      operations: 320,
      priceRm: 220,
      available: false,
      verified: true,
      initials: 'WT',
      bio:
          'Orthopaedic surgeon specialising in sports injuries and joint reconstruction.',
      yearsExperience: 15,
    ),
    MockDoctor(
      id: 'd3',
      name: 'Dr. Siti Nurhaliza',
      specialty: 'Paediatrics',
      hospital: 'Hospital Kuala Lumpur',
      hospitalType: 'Public',
      rating: 4.8,
      consultations: 1560,
      operations: 40,
      priceRm: 90,
      available: true,
      verified: true,
      initials: 'SN',
      bio:
          'Paediatric consultant with a focus on childhood development and immunisation.',
    ),
    MockDoctor(
      id: 'd4',
      name: 'Dr. Rajesh Menon',
      specialty: 'Physiotherapy',
      hospital: 'Prince Court Medical Centre',
      hospitalType: 'Private',
      rating: 4.6,
      consultations: 610,
      operations: 0,
      priceRm: 120,
      available: true,
      verified: false,
      initials: 'RM',
      bio:
          'Rehabilitation specialist supporting post-operative recovery programmes.',
    ),
  ];

  static const patients = [
    MockPatient(
        id: 'p1',
        name: 'Ahmad Faizal',
        birthday: '14 Feb 1990',
        city: 'Petaling Jaya',
        initials: 'AF'),
    MockPatient(
        id: 'p2',
        name: 'Lim Mei Ling',
        birthday: '3 Jun 1995',
        city: 'George Town',
        initials: 'LM'),
    MockPatient(
        id: 'p3',
        name: 'Nurul Izzah',
        birthday: '11 Sep 1988',
        city: 'Shah Alam',
        initials: 'NI'),
  ];

  static const managers = [
    MockManager(
        id: 'm1',
        name: 'Farah Aziz',
        level: 'General Manager',
        hospital: 'Pantai Hospital Kuala Lumpur',
        initials: 'FA'),
    MockManager(
        id: 'm2',
        name: 'Daniel Chong',
        level: 'Doctor Manager',
        hospital: 'Gleneagles Hospital Penang',
        initials: 'DC'),
  ];

  static const posts = [
    MockPost(
      id: 'post1',
      author: 'Dr. Aisha Rahman',
      role: 'Doctor',
      workplace: 'Pantai Hospital Kuala Lumpur',
      date: '4 Oct 2026',
      content:
          'Updated protocol for hypertension follow-up: confirm home BP logs before adjusting ACE inhibitors. Patient education remains the first intervention.',
      likes: 84,
      comments: 12,
      shares: 9,
      mediaLabel: 'Clinical chart',
      initials: 'AR',
    ),
    MockPost(
      id: 'post2',
      author: 'Physiotherapy Unit',
      role: 'Doctor',
      workplace: 'Prince Court Medical Centre',
      date: '3 Oct 2026',
      content:
          'Post-ACL reconstruction: week 2–4 range-of-motion goals and supervised load progression. Avoid unsupervised plyometrics until clearance.',
      likes: 51,
      comments: 7,
      shares: 14,
      mediaLabel: 'Rehabilitation video',
      initials: 'PT',
    ),
    MockPost(
      id: 'post3',
      author: 'Hospital Education',
      role: 'Manager',
      workplace: 'Hospital Kuala Lumpur',
      date: '1 Oct 2026',
      content:
          'New dengue case study: early warning signs, fluid management, and when to escalate to high-dependency care.',
      likes: 120,
      comments: 22,
      shares: 31,
      mediaLabel: 'Study PDF',
      initials: 'HE',
    ),
  ];

  static const chats = [
    MockChat(
        id: 'c1',
        title: 'Dr. Aisha Rahman',
        preview: 'Please confirm your appointment for Thursday 10:00.',
        time: '09:12',
        type: 'consultation',
        unread: 1),
    MockChat(
        id: 'c2',
        title: 'Orthopaedic collaboration',
        preview: 'Case notes attached for joint review.',
        time: 'Yesterday',
        type: 'collaboration',
        unread: 0),
    MockChat(
        id: 'c3',
        title: 'Hospital operations',
        preview: 'Schedule change for OT 3 on Friday.',
        time: 'Mon',
        type: 'manager',
        unread: 2),
    MockChat(
        id: 'c4',
        title: 'Public: Heart health',
        preview: 'Weekly briefing on cholesterol screening.',
        time: 'Sun',
        type: 'public',
        unread: 0),
    MockChat(
        id: 'c5',
        title: 'Private: Cardiology team',
        preview: 'Ward round notes uploaded.',
        time: 'Sat',
        type: 'private',
        unread: 0),
  ];

  static const applications = [
    MockApplication(
        id: 'a1',
        doctorName: 'Dr. Hana Yusof',
        specialty: 'Dermatology',
        hospital: 'Pantai Hospital Kuala Lumpur',
        submitted: '2 Oct 2026',
        status: 'Pending'),
    MockApplication(
        id: 'a2',
        doctorName: 'Dr. Kevin Ong',
        specialty: 'Neurology',
        hospital: 'Gleneagles Hospital Penang',
        submitted: '28 Sep 2026',
        status: 'Pending'),
    MockApplication(
        id: 'a3',
        doctorName: 'Dr. Priya Nair',
        specialty: 'Oncology',
        hospital: 'Prince Court Medical Centre',
        submitted: '20 Sep 2026',
        status: 'Rejected'),
  ];

  static const weekly = [
    ('Monday', '08:00–12:00', true),
    ('Tuesday', '14:00–18:00', true),
    ('Wednesday', 'Unavailable', false),
    ('Thursday', '09:00–13:00', true),
    ('Friday', '08:00–16:00', true),
    ('Saturday', '09:00–12:00', true),
    ('Sunday', 'Unavailable', false),
  ];
}
