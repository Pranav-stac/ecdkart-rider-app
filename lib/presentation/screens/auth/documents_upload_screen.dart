import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'bank_details_screen.dart';

class DocumentsUploadScreen extends StatefulWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String? pin;
  final String? profileImageBase64;
  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? regNumber;

  const DocumentsUploadScreen({
    super.key,
    this.name,
    this.email,
    this.phone,
    this.pin,
    this.profileImageBase64,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.regNumber,
  });

  @override
  State<DocumentsUploadScreen> createState() => _DocumentsUploadScreenState();
}

class _DocumentsUploadScreenState extends State<DocumentsUploadScreen> {
  final _formKey = GlobalKey<FormState>();

  // Driver License
  final _licenseNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  Uint8List? _licenseBytes;

  // PAN Card
  final _panNumberController = TextEditingController();
  Uint8List? _panBytes;

  // Aadhaar Card
  final _aadhaarNumberController = TextEditingController();
  Uint8List? _aadhaarBytes;

  final ImagePicker _picker = ImagePicker();
  static const Color primaryGreen = Color(0xFF248C70);

  Future<void> _pickDocumentImage(Function(Uint8List) onPicked) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Document Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final XFile? file = await _picker.pickImage(
                        source: ImageSource.camera, 
                        imageQuality: 85,
                        maxWidth: 1200,
                        maxHeight: 1200,
                      );
                      if (file != null) {
                        final bytes = await file.readAsBytes();
                        setState(() => onPicked(bytes));
                      }
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final XFile? file = await _picker.pickImage(
                        source: ImageSource.gallery, 
                        imageQuality: 85,
                        maxWidth: 1200,
                        maxHeight: 1200,
                      );
                      if (file != null) {
                        final bytes = await file.readAsBytes();
                        setState(() => onPicked(bytes));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryGreen, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C2C2C),
            ),
          ),
        ],
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      final licenseBase64 = _licenseBytes != null ? base64Encode(_licenseBytes!) : null;
      final panBase64 = _panBytes != null ? base64Encode(_panBytes!) : null;
      final aadhaarBase64 = _aadhaarBytes != null ? base64Encode(_aadhaarBytes!) : null;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BankDetailsScreen(
            name: widget.name,
            email: widget.email,
            phone: widget.phone,
            pin: widget.pin,
            profileImageBase64: widget.profileImageBase64,
            vehicleType: widget.vehicleType,
            vehicleBrand: widget.vehicleBrand,
            vehicleModel: widget.vehicleModel,
            vehicleYear: widget.vehicleYear,
            regNumber: widget.regNumber,
            licenseNumber: _licenseNumberController.text.trim(),
            licenseExpiry: _expiryDateController.text.trim(),
            licenseImageBase64: licenseBase64,
            panNumber: _panNumberController.text.trim(),
            panImageBase64: panBase64,
            aadhaarNumber: _aadhaarNumberController.text.trim(),
            aadhaarImageBase64: aadhaarBase64,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with Step indicator and banner
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'docs_header.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/docs_header.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF0FDF4),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: 10,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E1E1E), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                // Step (2) Badge
                Positioned(
                  top: 16,
                  right: 24,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '2',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                // Title and Progress Bar
                Positioned(
                  bottom: 12,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documents',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 3-Step Progress Bar (Step 1 & 2 active, Step 3 inactive)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Form Content (Driver License, PAN Card, Aadhaar Card)
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= SECTION 1: DRIVER LICENSE =================
                      _buildSectionHeader(
                        icon: Icons.drive_eta_rounded,
                        title: 'Driver License Details (Optional)',
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        label: 'Driver License Number (Optional)',
                        controller: _licenseNumberController,
                        hint: 'Enter license number (Optional)',
                        isOptional: true,
                      ),
                      const SizedBox(height: 12),

                      _buildUploadBox(
                        title: 'Driver License Photo (Optional)',
                        imageBytes: _licenseBytes,
                        onTap: () => _pickDocumentImage((bytes) => _licenseBytes = bytes),
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        label: 'License Expiry Date (Optional)',
                        controller: _expiryDateController,
                        hint: 'DD/MM/YYYY (Optional)',
                        isOptional: true,
                      ),

                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ================= SECTION 2: PAN CARD =================
                      _buildSectionHeader(
                        icon: Icons.credit_card_rounded,
                        title: 'PAN Card Details',
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        label: 'PAN Card Number',
                        controller: _panNumberController,
                        hint: 'Enter 10-digit PAN (e.g. ABCDE1234F)',
                      ),
                      const SizedBox(height: 12),

                      _buildUploadBox(
                        title: 'PAN Card Document Photo',
                        imageBytes: _panBytes,
                        onTap: () => _pickDocumentImage((bytes) => _panBytes = bytes),
                      ),

                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ================= SECTION 3: AADHAAR CARD =================
                      _buildSectionHeader(
                        icon: Icons.badge_rounded,
                        title: 'Aadhaar Card Details',
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        label: 'Aadhaar Card Number',
                        controller: _aadhaarNumberController,
                        hint: 'Enter 12-digit Aadhaar Number',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      _buildUploadBox(
                        title: 'Aadhaar Card Photo',
                        imageBytes: _aadhaarBytes,
                        onTap: () => _pickDocumentImage((bytes) => _aadhaarBytes = bytes),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Submit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: primaryGreen.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Next',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryGreen, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadBox({
    required String title,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
  }) {
    final bool isUploaded = imageBytes != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 125,
        decoration: BoxDecoration(
          color: isUploaded ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded ? primaryGreen : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        child: isUploaded
            ? Row(
                children: [
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Document Uploaded',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF2C2C2C)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to change photo',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    color: Colors.grey[700],
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tap to capture / upload (JPG, PNG)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF2C2C2C),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
            ),
            validator: (value) {
              if (!isOptional && (value == null || value.isEmpty)) {
                return 'Please enter $label';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _expiryDateController.dispose();
    _panNumberController.dispose();
    _aadhaarNumberController.dispose();
    super.dispose();
  }
}
