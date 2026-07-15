import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

/// 3-step rider onboarding registration flow
class RiderRegisterScreen extends StatefulWidget {
  const RiderRegisterScreen({super.key});

  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  int _currentStep = 0;
  final _pageController = PageController();

  // Step 1 – Personal Info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Step 2 – Credentials & Vehicle
  final _licenseCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  String _selectedVehicle = 'motorbike';
  final _vehicleRegCtrl = TextEditingController();

  // Step 3 – Documents
  bool _licenseUploaded = false;
  bool _idUploaded = false;
  bool _photoUploaded = false;

  bool _isLoading = false;

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/rider/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/login'),
              ),
        title: Text('Join the Fleet',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // ── Step progress indicator ──────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_currentStep + 1} of 3',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                        height: 5,
                        decoration: BoxDecoration(
                          color: index <= _currentStep
                              ? theme.colorScheme.primary
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── Page content ──────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1PersonalInfo(
                    nameCtrl: _nameCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    addressCtrl: _addressCtrl),
                _Step2CredentialsVehicle(
                    licenseCtrl: _licenseCtrl,
                    nationalIdCtrl: _nationalIdCtrl,
                    vehicleRegCtrl: _vehicleRegCtrl,
                    selectedVehicle: _selectedVehicle,
                    onVehicleChanged: (v) =>
                        setState(() => _selectedVehicle = v)),
                _Step3Documents(
                    licenseUploaded: _licenseUploaded,
                    idUploaded: _idUploaded,
                    photoUploaded: _photoUploaded,
                    onUpload: (type) => setState(() {
                          if (type == 'license') _licenseUploaded = true;
                          if (type == 'id') _idUploaded = true;
                          if (type == 'photo') _photoUploaded = true;
                        })),
              ],
            ),
          ),

          // ── Bottom CTA ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _currentStep == 2
                            ? 'Submit Application'
                            : 'Continue',
                        style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Personal Info ─────────────────────────────────────────────────────

class _Step1PersonalInfo extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;

  const _Step1PersonalInfo({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Details',
              style:
                  TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          const Text(
              'Enter your personal information to get started as an EcoWaste Rider.',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          // Avatar placeholder
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(Icons.person,
                      size: 48, color: Colors.grey.shade400),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0A500),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _FormLabel('Full Name'),
          const SizedBox(height: 6),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Marcus Sterling',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          _FormLabel('Email Address'),
          const SizedBox(height: 6),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'e.g. rider@ecowaste.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          _FormLabel('Phone Number'),
          const SizedBox(height: 6),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+1 (555) 000-0000',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          _FormLabel('Home Address'),
          const SizedBox(height: 6),
          TextField(
            controller: addressCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. 12 Oak Street, North District',
              prefixIcon: const Icon(Icons.home_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Credentials & Vehicle ─────────────────────────────────────────────

class _Step2CredentialsVehicle extends StatelessWidget {
  final TextEditingController licenseCtrl;
  final TextEditingController nationalIdCtrl;
  final TextEditingController vehicleRegCtrl;
  final String selectedVehicle;
  final ValueChanged<String> onVehicleChanged;

  const _Step2CredentialsVehicle({
    required this.licenseCtrl,
    required this.nationalIdCtrl,
    required this.vehicleRegCtrl,
    required this.selectedVehicle,
    required this.onVehicleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Credentials & Vehicle',
              style:
                  TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          const Text(
              'Step 2 of 3. Verify your rider credentials and select your vehicle type.',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          _FormLabel('Driver License Number'),
          const SizedBox(height: 6),
          TextField(
            controller: licenseCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. DL-GH-20240312',
              prefixIcon: const Icon(Icons.credit_card_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          _FormLabel('National ID Number'),
          const SizedBox(height: 6),
          TextField(
            controller: nationalIdCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. GHA-0012345678',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          _FormLabel('Vehicle Registration'),
          const SizedBox(height: 6),
          TextField(
            controller: vehicleRegCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. GH-1234-23',
              prefixIcon: const Icon(Icons.directions_car_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          _FormLabel('Vehicle Type'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: [
              _VehicleCard(
                label: 'Motorbike',
                icon: Icons.two_wheeler,
                value: 'motorbike',
                selected: selectedVehicle == 'motorbike',
                onTap: () => onVehicleChanged('motorbike'),
              ),
              _VehicleCard(
                label: 'Compact Van',
                icon: Icons.airport_shuttle,
                value: 'compact_van',
                selected: selectedVehicle == 'compact_van',
                onTap: () => onVehicleChanged('compact_van'),
              ),
              _VehicleCard(
                label: 'Cargo Bike',
                icon: Icons.pedal_bike,
                value: 'cargo_bike',
                selected: selectedVehicle == 'cargo_bike',
                onTap: () => onVehicleChanged('cargo_bike'),
              ),
              _VehicleCard(
                label: 'Heavy Duty',
                icon: Icons.local_shipping,
                value: 'heavy_duty',
                selected: selectedVehicle == 'heavy_duty',
                onTap: () => onVehicleChanged('heavy_duty'),
              ),
              _VehicleCard(
                label: 'Pickup Truck',
                icon: Icons.fire_truck,
                value: 'pickup_truck',
                selected: selectedVehicle == 'pickup_truck',
                onTap: () => onVehicleChanged('pickup_truck'),
              ),
              _VehicleCard(
                label: 'Electric Van',
                icon: Icons.electric_car,
                value: 'electric_van',
                selected: selectedVehicle == 'electric_van',
                onTap: () => onVehicleChanged('electric_van'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : (isDark ? theme.cardTheme.color : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade500,
                size: 28),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Documents ─────────────────────────────────────────────────────────

class _Step3Documents extends StatelessWidget {
  final bool licenseUploaded;
  final bool idUploaded;
  final bool photoUploaded;
  final void Function(String type) onUpload;

  const _Step3Documents({
    required this.licenseUploaded,
    required this.idUploaded,
    required this.photoUploaded,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Document Verification',
              style:
                  TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          const Text(
              'To ensure the safety of our operations, please upload clear photos of your identity documents.',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          _UploadTile(
            title: 'Proof of Identity',
            subtitle: 'National ID Card (both sides)',
            icon: Icons.badge_outlined,
            uploaded: idUploaded,
            onTap: () => onUpload('id'),
          ),
          const SizedBox(height: 12),
          _UploadTile(
            title: 'Driver License Photo',
            subtitle: 'Clear front-face photo of license',
            icon: Icons.credit_card_outlined,
            uploaded: licenseUploaded,
            onTap: () => onUpload('license'),
          ),
          const SizedBox(height: 12),
          _UploadTile(
            title: 'Selfie or Profile Photo',
            subtitle: 'Recent clear photo of yourself',
            icon: Icons.portrait,
            uploaded: photoUploaded,
            onTap: () => onUpload('photo'),
          ),
          const SizedBox(height: 24),

          // Upload requirements note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text('Upload Requirements',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final req in [
                  'Images must be clear and in focus',
                  'Accepted formats: JPG, PNG (max 10MB)',
                  'All text on document must be readable',
                  'No screenshots – original photos only',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.blue.shade600, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(req,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool uploaded;
  final VoidCallback onTap;

  const _UploadTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.uploaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: uploaded
              ? Colors.green.shade50
              : (isDark ? theme.cardTheme.color : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: uploaded ? Colors.green.shade300 : Colors.grey.shade200,
            width: uploaded ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: uploaded
                    ? Colors.green.withOpacity(0.12)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                uploaded ? Icons.check : icon,
                color: uploaded ? Colors.green : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (uploaded)
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 22)
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0A500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFF0A500).withOpacity(0.4)),
                ),
                child: const Text('Upload',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0A500))),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14));
  }
}
