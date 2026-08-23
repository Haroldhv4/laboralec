import '../core/formatters.dart';

class Company {
  const Company({
    required this.id,
    required this.ownerId,
    required this.legalName,
    this.tradeName,
    this.ruc,
    this.province,
    this.city,
    this.region,
  });

  final String id;
  final String ownerId;
  final String legalName;
  final String? tradeName;
  final String? ruc;
  final String? province;
  final String? city;
  final String? region;

  String get displayName =>
      (tradeName?.trim().isNotEmpty ?? false) ? tradeName!.trim() : legalName;

  factory Company.fromMap(Map<String, dynamic> map) => Company(
        id: map['id'].toString(),
        ownerId: map['owner_id'].toString(),
        legalName: map['legal_name']?.toString() ?? 'Empresa',
        tradeName: map['trade_name']?.toString(),
        ruc: map['ruc']?.toString(),
        province: map['province']?.toString(),
        city: map['city']?.toString(),
        region: map['region']?.toString(),
      );
}

class Employee {
  const Employee({
    required this.id,
    required this.companyId,
    required this.identificationNumber,
    required this.firstNames,
    required this.lastNames,
    this.email,
    this.phone,
    this.status = 'active',
  });

  final String id;
  final String companyId;
  final String identificationNumber;
  final String firstNames;
  final String lastNames;
  final String? email;
  final String? phone;
  final String status;

  String get fullName => '$firstNames $lastNames'.trim();

  factory Employee.fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'].toString(),
        companyId: map['company_id'].toString(),
        identificationNumber: map['identification_number']?.toString() ?? '',
        firstNames: map['first_names']?.toString() ?? '',
        lastNames: map['last_names']?.toString() ?? '',
        email: map['email']?.toString(),
        phone: map['phone']?.toString(),
        status: map['status']?.toString() ?? 'active',
      );
}

class EmploymentContract {
  const EmploymentContract({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.startDate,
    required this.monthlySalary,
    this.position,
    this.contractType = 'indefinite',
    this.weeklyHours = 40,
    this.status = 'active',
    this.thirteenthPaymentMode = 'monthly',
    this.fourteenthPaymentMode = 'monthly',
    this.reserveFundPaymentMode = 'iess',
  });

  final String id;
  final String employeeId;
  final String companyId;
  final DateTime startDate;
  final double monthlySalary;
  final String? position;
  final String contractType;
  final double weeklyHours;
  final String status;
  final String thirteenthPaymentMode;
  final String fourteenthPaymentMode;
  final String reserveFundPaymentMode;

  factory EmploymentContract.fromMap(Map<String, dynamic> map) =>
      EmploymentContract(
        id: map['id'].toString(),
        employeeId: map['employee_id'].toString(),
        companyId: map['company_id'].toString(),
        startDate: parseDate(map['start_date']) ?? DateTime.now(),
        monthlySalary: asDouble(map['monthly_salary']),
        position: map['position']?.toString(),
        contractType: map['contract_type']?.toString() ?? 'indefinite',
        weeklyHours: asDouble(map['weekly_hours']) == 0
            ? 40
            : asDouble(map['weekly_hours']),
        status: map['status']?.toString() ?? 'active',
        thirteenthPaymentMode:
            map['thirteenth_payment_mode']?.toString() ?? 'monthly',
        fourteenthPaymentMode:
            map['fourteenth_payment_mode']?.toString() ?? 'monthly',
        reserveFundPaymentMode:
            map['reserve_fund_payment_mode']?.toString() ?? 'iess',
      );
}

class EmployeeRecord {
  const EmployeeRecord({required this.employee, required this.contract});

  final Employee employee;
  final EmploymentContract? contract;
}
