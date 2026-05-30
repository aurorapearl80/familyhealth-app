import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Fetches and caches the authenticated patient's profile from the server.
class PatientService extends ChangeNotifier {
  static const _endpoint =
      'https://familywatchtoday.com/api/auth-monitoring/patient';
  static const _p = 'patient_'; // SharedPreferences key prefix

  bool _isLoading = false;
  String? _error;

  // ── Personal ───────────────────────────────────────────────────────────────
  String? _fullName;
  String? _firstName;
  String? _lastName;
  String? _email;
  String? _phone;
  String? _homeNumber;
  String? _dateOfBirth;
  String? _gender;
  String? _state;
  String? _country;
  String? _completeAddress;
  String? _zipCode;

  // ── Organization ───────────────────────────────────────────────────────────
  String? _organization;
  String? _memberId;
  String? _status;
  List<String> _enrolledPrograms = [];

  // ── Medical ────────────────────────────────────────────────────────────────
  String? _height;
  String? _weight;
  String? _generalPractitioner;
  List<String> _conditions = [];
  List<String> _practitioners = [];
  String? _angelSupport;
  String? _glucoseTestRate;

  // ── Insurance ──────────────────────────────────────────────────────────────
  String? _primaryInsuranceName;
  String? _primaryInsurancePolicyId;
  String? _primaryInsuranceGroupNumber;
  String? _primaryInsurancePhone;
  String? _secondaryInsuranceName;
  String? _secondaryInsurancePolicyId;
  String? _secondaryInsurancePhone;

  // ── Media ──────────────────────────────────────────────────────────────────
  String? _profileImageUrl;

  // ── Measurement units ──────────────────────────────────────────────────────
  String? _unitHeight;
  String? _unitWeight;
  String? _unitTemperature;
  String? _unitGlucose;
  String? _unitBloodPressure;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get fullName => _fullName;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get email => _email;
  String? get phone => _phone;
  String? get homeNumber => _homeNumber;
  String? get dateOfBirth => _dateOfBirth;
  String? get gender => _gender;
  String? get state => _state;
  String? get country => _country;
  String? get completeAddress => _completeAddress;
  String? get zipCode => _zipCode;

  String? get organization => _organization;
  String? get memberId => _memberId;
  String? get status => _status;
  List<String> get enrolledPrograms => List.unmodifiable(_enrolledPrograms);

  String? get height => _height;
  String? get weight => _weight;
  String? get generalPractitioner => _generalPractitioner;
  List<String> get conditions => List.unmodifiable(_conditions);
  List<String> get practitioners => List.unmodifiable(_practitioners);
  String? get angelSupport => _angelSupport;
  String? get glucoseTestRate => _glucoseTestRate;

  String? get primaryInsuranceName => _primaryInsuranceName;
  String? get primaryInsurancePolicyId => _primaryInsurancePolicyId;
  String? get primaryInsuranceGroupNumber => _primaryInsuranceGroupNumber;
  String? get primaryInsurancePhone => _primaryInsurancePhone;
  String? get secondaryInsuranceName => _secondaryInsuranceName;
  String? get secondaryInsurancePolicyId => _secondaryInsurancePolicyId;
  String? get secondaryInsurancePhone => _secondaryInsurancePhone;

  String? get profileImageUrl => _profileImageUrl;

  String? get unitHeight => _unitHeight;
  String? get unitWeight => _unitWeight;
  String? get unitTemperature => _unitTemperature;
  String? get unitGlucose => _unitGlucose;
  String? get unitBloodPressure => _unitBloodPressure;

  // ── Computed ───────────────────────────────────────────────────────────────
  String get displayName => _firstName ?? _fullName?.split(',').last.trim() ?? 'User';

  String get initials {
    final f = (_firstName?.isNotEmpty == true) ? _firstName![0].toUpperCase() : '';
    final l = (_lastName?.isNotEmpty == true) ? _lastName![0].toUpperCase() : '';
    final combined = '$f$l';
    return combined.isNotEmpty ? combined : 'U';
  }

  int? get age {
    if (_dateOfBirth == null) return null;
    final dob = DateTime.tryParse(_dateOfBirth!);
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    // Pre-populate from cache immediately
    await _loadFromPrefs();

    final token = await AuthService.getToken();
    if (token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(_endpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _parseResponse(data);
        await _saveToPrefs();
        debugPrint('[Patient] loaded — $_firstName $_lastName | img=$_profileImageUrl');
      } else {
        _error = 'Server error (${response.statusCode})';
        debugPrint('[Patient] fetch failed ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Network error';
      debugPrint('[Patient] fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  void _parseResponse(Map<String, dynamic> d) {
    _fullName = d['full_name'] as String?;
    _firstName = d['first_name'] as String?;
    _lastName = d['last_name'] as String?;
    _email = d['email'] as String?;
    _phone = d['phone'] as String?;
    _homeNumber = d['home_number'] as String?;
    _dateOfBirth = d['date_of_birth'] as String?;
    _gender = d['gender'] as String?;
    _state = d['state'] as String?;
    _country = d['country'] as String?;
    _completeAddress = d['complete_address'] as String?;
    _zipCode = d['zip_code'] as String?;
    _organization = d['organization'] as String?;
    _memberId = d['member_id'] as String?;
    _status = d['status'] as String?;
    _height = d['height'] as String?;
    _weight = d['weight'] as String?;
    _generalPractitioner = d['general_practitioner'] as String?;
    _angelSupport = d['angel_support'] as String?;
    _glucoseTestRate = d['glucose_test_rate'] as String?;
    _profileImageUrl = d['profile_image_url'] as String?;

    _conditions = _strList(d['conditions']);
    _practitioners = _strList(d['practitioners']);
    _enrolledPrograms = _strList(d['enrolled_programs']);

    _primaryInsuranceName = d['primary_insurance_name'] as String?;
    _primaryInsurancePolicyId = d['primary_insurance_policy_id'] as String?;
    _primaryInsuranceGroupNumber = d['primary_insurance_group_number'] as String?;
    _primaryInsurancePhone = d['primary_insurance_phone'] as String?;
    _secondaryInsuranceName = d['secondary_insurance_name'] as String?;
    _secondaryInsurancePolicyId = d['secondary_insurance_policy_id'] as String?;
    _secondaryInsurancePhone = d['secondary_insurance_phone'] as String?;

    final units = d['measurement_units'] as Map<String, dynamic>?;
    if (units != null) {
      _unitHeight = units['unit_height'] as String?;
      _unitWeight = units['unit_weight'] as String?;
      _unitTemperature = units['unit_temperature'] as String?;
      _unitGlucose = units['unit_glucose'] as String?;
      _unitBloodPressure = units['unit_blood_pressure'] as String?;
    }
  }

  static List<String> _strList(dynamic raw) =>
      (raw as List?)?.map((e) => e.toString()).toList() ?? [];

  // ── SharedPreferences cache ────────────────────────────────────────────────

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    void s(String key, String? v) {
      if (v != null) {
        prefs.setString('$_p$key', v);
      } else {
        prefs.remove('$_p$key');
      }
    }

    s('full_name', _fullName);
    s('first_name', _firstName);
    s('last_name', _lastName);
    s('email', _email);
    s('phone', _phone);
    s('home_number', _homeNumber);
    s('date_of_birth', _dateOfBirth);
    s('gender', _gender);
    s('state', _state);
    s('country', _country);
    s('complete_address', _completeAddress);
    s('zip_code', _zipCode);
    s('organization', _organization);
    s('member_id', _memberId);
    s('status', _status);
    s('height', _height);
    s('weight', _weight);
    s('general_practitioner', _generalPractitioner);
    s('angel_support', _angelSupport);
    s('glucose_test_rate', _glucoseTestRate);
    s('profile_image_url', _profileImageUrl);
    s('primary_insurance_name', _primaryInsuranceName);
    s('primary_insurance_policy_id', _primaryInsurancePolicyId);
    s('primary_insurance_group_number', _primaryInsuranceGroupNumber);
    s('primary_insurance_phone', _primaryInsurancePhone);
    s('secondary_insurance_name', _secondaryInsuranceName);
    s('secondary_insurance_policy_id', _secondaryInsurancePolicyId);
    s('secondary_insurance_phone', _secondaryInsurancePhone);
    s('unit_height', _unitHeight);
    s('unit_weight', _unitWeight);
    s('unit_temperature', _unitTemperature);
    s('unit_glucose', _unitGlucose);
    s('unit_blood_pressure', _unitBloodPressure);

    prefs.setString('${_p}conditions', jsonEncode(_conditions));
    prefs.setString('${_p}practitioners', jsonEncode(_practitioners));
    prefs.setString('${_p}enrolled_programs', jsonEncode(_enrolledPrograms));
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String? g(String key) => prefs.getString('$_p$key');

    _fullName = g('full_name');
    _firstName = g('first_name');
    _lastName = g('last_name');
    _email = g('email');
    _phone = g('phone');
    _homeNumber = g('home_number');
    _dateOfBirth = g('date_of_birth');
    _gender = g('gender');
    _state = g('state');
    _country = g('country');
    _completeAddress = g('complete_address');
    _zipCode = g('zip_code');
    _organization = g('organization');
    _memberId = g('member_id');
    _status = g('status');
    _height = g('height');
    _weight = g('weight');
    _generalPractitioner = g('general_practitioner');
    _angelSupport = g('angel_support');
    _glucoseTestRate = g('glucose_test_rate');
    _profileImageUrl = g('profile_image_url');
    _primaryInsuranceName = g('primary_insurance_name');
    _primaryInsurancePolicyId = g('primary_insurance_policy_id');
    _primaryInsuranceGroupNumber = g('primary_insurance_group_number');
    _primaryInsurancePhone = g('primary_insurance_phone');
    _secondaryInsuranceName = g('secondary_insurance_name');
    _secondaryInsurancePolicyId = g('secondary_insurance_policy_id');
    _secondaryInsurancePhone = g('secondary_insurance_phone');
    _unitHeight = g('unit_height');
    _unitWeight = g('unit_weight');
    _unitTemperature = g('unit_temperature');
    _unitGlucose = g('unit_glucose');
    _unitBloodPressure = g('unit_blood_pressure');

    _conditions = _decodeList(prefs.getString('${_p}conditions'));
    _practitioners = _decodeList(prefs.getString('${_p}practitioners'));
    _enrolledPrograms = _decodeList(prefs.getString('${_p}enrolled_programs'));
  }

  static List<String> _decodeList(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Clear (logout) ─────────────────────────────────────────────────────────

  void clear() {
    _fullName = _firstName = _lastName = _email = _phone = null;
    _homeNumber = _dateOfBirth = _gender = _state = _country = null;
    _completeAddress = _zipCode = _organization = _memberId = _status = null;
    _height = _weight = _generalPractitioner = _angelSupport = null;
    _glucoseTestRate = _profileImageUrl = null;
    _primaryInsuranceName = _primaryInsurancePolicyId = null;
    _primaryInsuranceGroupNumber = _primaryInsurancePhone = null;
    _secondaryInsuranceName = _secondaryInsurancePolicyId = null;
    _secondaryInsurancePhone = null;
    _unitHeight = _unitWeight = _unitTemperature = null;
    _unitGlucose = _unitBloodPressure = null;
    _conditions = [];
    _practitioners = [];
    _enrolledPrograms = [];
    _error = null;
    notifyListeners();
  }
}