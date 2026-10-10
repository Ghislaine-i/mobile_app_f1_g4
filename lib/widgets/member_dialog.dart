import 'package:flutter/material.dart';

import '../models/models.dart';
import 'ui_helpers.dart';

// Small form used to add or edit a member (and to edit the profile).
class MemberDialog extends StatefulWidget {
  const MemberDialog({super.key, required this.title, this.member});
  final String title;
  final TeamMember? member;

  @override
  State<MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<MemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name);
  late String? _role = widget.member?.role;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      TeamMember(id: widget.member?.id, name: _name.text.trim(), role: _role!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a name.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [
                      for (final r in roles)
                        DropdownMenuItem(value: r, child: Text(r)),
                    ],
                    onChanged: (v) => setState(() => _role = v),
                    validator: (v) => v == null ? 'Choose a role.' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DialogActionButtons(
              primaryLabel: 'Save',
              onPrimary: _save,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
