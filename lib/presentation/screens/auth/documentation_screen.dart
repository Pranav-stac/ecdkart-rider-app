import 'package:vegbox_driver_app/widgets/safe_image.dart';
import 'dart:io';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/api_service.dart';
import '../../../data/models/user_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vegbox_driver_app/logic/blocs/auth/auth_event.dart';
import '../home/driver_home_screen.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_state.dart';

class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiController = TextEditingController();

  XFile? _profileImage;
  XFile? _aadharFrontImage;
  XFile? _aadharBackImage;
  XFile? _dlImage;

  final ImagePicker _picker = ImagePicker();
  bool _isContinueEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _nameController.addListener(_validateForm);
    _upiController.addListener(_validateForm);
  }

  void _loadUserData() {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      _phoneController.text = state.user.phone;
      _nameController.text = state.user.name ?? '';
      _upiController.text = state.user.upi ?? '';
    }
  }

  Future<void> _pickImage(String type) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: type == 'profile' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        if (type == 'profile') _profileImage = pickedFile;
        if (type == 'aadhar_front') _aadharFrontImage = pickedFile;
        if (type == 'aadhar_back') _aadharBackImage = pickedFile;
        if (type == 'dl') _dlImage = pickedFile;
      });
      _validateForm();
    }
  }

  Widget _buildImageWidget(XFile file, {double? width, double? height}) {
    if (kIsWeb) {
      return SafeImage(file.path, width: width, height: height, fit: BoxFit.cover);
    } else {
      return Image.file(File(file.path), width: width, height: height, fit: BoxFit.cover);
    }
  }

  void _validateForm() {
    setState(() {
      _isContinueEnabled = _nameController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _upiController.text.isNotEmpty &&
          _profileImage != null &&
          _aadharFrontImage != null &&
          _aadharBackImage != null &&
          _dlImage != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Documentation'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide the following details to continue',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Profile Photo
                _buildLabel('Click Your Picture'),
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage('profile'),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: _profileImage != null ? Theme.of(context).primaryColor : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: _profileImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: _buildImageWidget(_profileImage!),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 4),
                                Text('Take Photo', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Name Field
                _buildLabel('Full Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Enter your full name', Icons.person),
                ),
                const SizedBox(height: 20),

                // Phone Field (Read-only)
                _buildLabel('Phone Number'),
                TextFormField(
                  controller: _phoneController,
                  enabled: false,
                  decoration: _buildInputDecoration('', Icons.phone).copyWith(
                    fillColor: Colors.grey[100],
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),

                // UPI Number / ID Field
                _buildLabel('UPI ID / Number'),
                TextFormField(
                  controller: _upiController,
                  decoration: _buildInputDecoration('Enter your UPI ID (e.g. name@upi)', Icons.account_balance_wallet),
                ),
                const SizedBox(height: 24),

                // Document Uploads
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDocumentUpload(
                        'Aadhar Front',
                        _aadharFrontImage,
                        () => _pickImage('aadhar_front'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDocumentUpload(
                        'Aadhar Back',
                        _aadharBackImage,
                        () => _pickImage('aadhar_back'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDocumentUpload(
                  'Driving License',
                  _dlImage,
                  () => _pickImage('dl'),
                ),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isContinueEnabled
                        ? () async {
                            // Show Loading Dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFF22C55E),
                                ),
                              ),
                            );

                            try {
                              final state = context.read<AuthBloc>().state;
                              if (state is Authenticated) {
                                // Call real backend upload
                                final result = await ApiService.uploadDriverDocuments(
                                  name: _nameController.text,
                                  upi: _upiController.text,
                                  email: state.user.email,
                                  profileImage: _profileImage,
                                  aadharFront: _aadharFrontImage,
                                  aadharBack: _aadharBackImage,
                                  license: _dlImage,
                                );

                                // Dismiss Loading Dialog immediately after request finishes
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }

                                if (result['success'] == true) {
                                  final responseUserJson = result['data']['user'];
                                  if (responseUserJson != null) {
                                    // Decode the updated UserModel returned by backend
                                    final updatedUser = UserModel.fromJson(responseUserJson);
                                    context.read<AuthBloc>().add(UpdateUserData(user: updatedUser));
                                  }

                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                                      (route) => false,
                                    );
                                  }
                                } else {
                                  // Extract message from result['data'] if available
                                  final errorMessage = (result['data'] != null && result['data']['message'] != null)
                                      ? result['data']['message']
                                      : (result['message'] ?? 'Server error');
                                      
                                  // Show snackbar alert on error
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Upload Failed: $errorMessage'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                                log("Upload process error: $e");
                                // Dismiss Loading Dialog if it's still showing due to error
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Upload Error: $e'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentUpload(String label, XFile? image, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  image != null ? Icons.check_circle : Icons.upload_file,
                  color: image != null ? Theme.of(context).primaryColor : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    image != null ? 'Document Uploaded' : 'Tap to Upload $label',
                    style: TextStyle(
                      color: image != null ? Theme.of(context).primaryColor : Colors.grey[700],
                      fontWeight: image != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _buildImageWidget(image, width: 40, height: 40),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    super.dispose();
  }
}
