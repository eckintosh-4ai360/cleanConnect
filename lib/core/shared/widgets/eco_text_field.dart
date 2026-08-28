import 'package:flutter/material.dart';

class CleanConnectTextField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const CleanConnectTextField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<CleanConnectTextField> createState() => _CleanConnectTextFieldState();
}

class _CleanConnectTextFieldState extends State<CleanConnectTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.labelText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.controller,
            obscureText: widget.isPassword ? _obscureText : false,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onBackground,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : widget.suffixIcon,
            ),
          ),
        ],
      ),
    );
  }
}

typedef EcoTextField = CleanConnectTextField;

