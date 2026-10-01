import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_models.dart';
import '../services/api_service.dart';
import 'terms_conditions_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final ApiService _apiService = ApiService();

  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  // Data Lists
  List<StateModel> _states = [];
  List<DistrictModel> _districts = [];
  List<TalukaModel> _talukas = [];
  List<VillageModel> _villages = [];

  // Selected Values
  int? _selectedStateId;
  int? _selectedDistrictId;
  int? _selectedTalukaId;
  int? _selectedVillageId;

  // Loading States
  bool _isLoadingStates = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingTalukas = false;
  bool _isLoadingVillages = false;
  bool _isFetchingLocation = false;

  // Terms Checkbox
  bool _isTermsAccepted = false;

  @override
  void initState() {
    super.initState();
    _fetchStates();
  }

  // --- API Calls ---

  Future<void> _fetchStates() async {
    setState(() => _isLoadingStates = true);
    final data = await _apiService.getStates();
    setState(() {
      _states = data;
      _isLoadingStates = false;
    });
  }

  Future<void> _fetchDistricts(int stateId) async {
    setState(() {
      _isLoadingDistricts = true;
      _districts = [];
      _talukas = [];
      _villages = [];
      _selectedDistrictId = null;
      _selectedTalukaId = null;
      _selectedVillageId = null;
    });
    final data = await _apiService.getDistricts(stateId);
    setState(() {
      _districts = data;
      _isLoadingDistricts = false;
    });
  }

  Future<void> _fetchTalukas(int stateId, int districtId) async {
    setState(() {
      _isLoadingTalukas = true;
      _talukas = [];
      _villages = [];
      _selectedTalukaId = null;
      _selectedVillageId = null;
    });
    final data = await _apiService.getTalukas(stateId, districtId);
    setState(() {
      _talukas = data;
      _isLoadingTalukas = false;
    });
  }

  Future<void> _fetchVillages(int stateId, int districtId, int talukaId) async {
    setState(() {
      _isLoadingVillages = true;
      _villages = [];
      _selectedVillageId = null;
    });
    final data = await _apiService.getVillages(stateId, districtId, talukaId);
    setState(() {
      _villages = data;
      _isLoadingVillages = false;
    });
  }

  // --- Location Logic ---

  Future<void> _getLiveLocation() async {
    setState(() => _isFetchingLocation = true);
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      setState(() => _isFetchingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        setState(() => _isFetchingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      setState(() => _isFetchingLocation = false);
      return;
    }

    // Get Position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Get Address from Coordinates (Reverse Geocoding)
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Auto-fill the address field
        String address = "${place.street}, ${place.locality}, ${place.subAdministrativeArea}, ${place.postalCode}";
        _addressController.text = address;
      }
    } catch (e) {
      print("Geocoding error: $e");
      _addressController.text = "${position.latitude}, ${position.longitude}";
    }

    setState(() => _isFetchingLocation = false);
  }

  // --- Terms Logic ---

  void _openTermsPopup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsConditionsScreen()),
    );

    if (result == true) {
      setState(() {
        _isTermsAccepted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Company Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Address Section ---
              const Text("Address Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Live Location Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isFetchingLocation ? null : _getLiveLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(_isFetchingLocation ? "Fetching..." : "Get My Live Location"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Address Field
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: "Full Address",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
                validator: (value) => value!.isEmpty ? "Address is required" : null,
              ),
              const SizedBox(height: 15),

              // Pincode
              TextFormField(
                controller: _pincodeController,
                decoration: const InputDecoration(
                  labelText: "Pincode",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_drop),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Pincode is required" : null,
              ),
              const SizedBox(height: 25),

              // --- Location Dropdowns ---
              const Text("Region Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // State Dropdown
              _buildDropdown<StateModel>(
                label: "State",
                value: _selectedStateId,
                items: _states,
                isLoading: _isLoadingStates,
                onChanged: (val) {
                  setState(() => _selectedStateId = val);
                  if (val != null) _fetchDistricts(val);
                },
                itemLabel: (item) => item.name,
                itemValue: (item) => item.id,
              ),
              const SizedBox(height: 15),

              // District Dropdown
              _buildDropdown<DistrictModel>(
                label: "District",
                value: _selectedDistrictId,
                items: _districts,
                isLoading: _isLoadingDistricts,
                onChanged: (val) {
                  setState(() => _selectedDistrictId = val);
                  if (val != null && _selectedStateId != null) {
                    _fetchTalukas(_selectedStateId!, val);
                  }
                },
                itemLabel: (item) => item.name,
                itemValue: (item) => item.id,
              ),
              const SizedBox(height: 15),

              // Taluka Dropdown
              _buildDropdown<TalukaModel>(
                label: "Taluka",
                value: _selectedTalukaId,
                items: _talukas,
                isLoading: _isLoadingTalukas,
                onChanged: (val) {
                  setState(() => _selectedTalukaId = val);
                  if (val != null && _selectedStateId != null && _selectedDistrictId != null) {
                    _fetchVillages(_selectedStateId!, _selectedDistrictId!, val);
                  }
                },
                itemLabel: (item) => item.name,
                itemValue: (item) => item.id,
              ),
              const SizedBox(height: 15),

              // Village Dropdown
              _buildDropdown<VillageModel>(
                label: "Village",
                value: _selectedVillageId,
                items: _villages,
                isLoading: _isLoadingVillages,
                onChanged: (val) {
                  setState(() => _selectedVillageId = val);
                },
                itemLabel: (item) => item.name,
                itemValue: (item) => item.id,
              ),
              const SizedBox(height: 30),

              // --- Terms & Conditions ---
              Row(
                children: [
                  Checkbox(
                    value: _isTermsAccepted,
                    onChanged: (val) {
                      setState(() => _isTermsAccepted = val!);
                    },
                    activeColor: Colors.green,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openTermsPopup,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          children: [
                            TextSpan(text: "I agree to the "),
                            TextSpan(
                              text: "Terms & Conditions",
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: " *", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (!_isTermsAccepted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please accept Terms & Conditions")),
                        );
                        return;
                      }
                      // Proceed with registration logic
                      print("Form Submitted");
                      print("State ID: $_selectedStateId");
                      print("District ID: $_selectedDistrictId");
                      print("Taluka ID: $_selectedTalukaId");
                      print("Village ID: $_selectedVillageId");
                      print("Address: ${_addressController.text}");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("Register", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Dropdowns
  Widget _buildDropdown<T>({
    required String label,
    required int? value,
    required List<T> items,
    required bool isLoading,
    required Function(int?) onChanged,
    required String Function(T) itemLabel,
    required int Function(T) itemValue,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      items: isLoading
          ? []
          : items.map((item) {
        return DropdownMenuItem<int>(
          value: itemValue(item),
          child: Text(itemLabel(item)),
        );
      }).toList(),
      onChanged: isLoading ? null : onChanged,
      validator: (val) => val == null ? "Please select $label" : null,
      hint: isLoading
          ? const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2)),
      )
          : Text("Select $label"),
    );
  }
}