import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/custom_command.dart';
import '../theme/app_theme.dart';

import '../utils/command_validator.dart';

class CustomCommandDialog extends StatefulWidget {
  final CustomCommand? existingCommand;

  const CustomCommandDialog({super.key, this.existingCommand});

  @override
  State<CustomCommandDialog> createState() => _CustomCommandDialogState();
}

class _CustomCommandDialogState extends State<CustomCommandDialog> {
  final _titleController = TextEditingController();
  final _commandController = TextEditingController();
  String _selectedIcon = 'terminal';
  String? _validationError;

  final Map<String, IconData> _availableIcons = {
    'terminal': Icons.terminal,
    'storage': Icons.storage,
    'save': Icons.save,
    'wifi': Icons.wifi,
    'network_check': Icons.network_check,
    'memory': Icons.memory,
    'build': Icons.build,
    'play_arrow': Icons.play_arrow,
    'bolt': Icons.bolt,
    'web': Icons.language,
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingCommand != null) {
      _titleController.text = widget.existingCommand!.title;
      _commandController.text = widget.existingCommand!.command;
      if (_availableIcons.containsKey(widget.existingCommand!.iconName)) {
        _selectedIcon = widget.existingCommand!.iconName;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final command = _commandController.text.trim();

    if (title.isEmpty || command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and Command are required.'),
          backgroundColor: AppTheme.crimson,
        ),
      );
      return;
    }

    final validation = CommandValidator.validateCustomCommand(command);
    if (validation.isBlocked) {
      setState(() {
        _validationError = validation.message ?? 'Blocked: Invalid command.';
      });
      return;
    }
    
    setState(() {
      _validationError = null;
    });

    final customCommand = CustomCommand(
      id: widget.existingCommand?.id ?? CustomCommand.generateId(),
      title: title,
      command: command,
      iconName: _selectedIcon,
    );

    Navigator.pop(context, customCommand);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(
        widget.existingCommand == null ? 'Add Custom Command' : 'Edit Custom Command',
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a quick-action button for a custom non-root command.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              
              // Title
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Button Title',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: AppTheme.obsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.title, color: AppTheme.neonCyan),
                ),
              ),
              const SizedBox(height: 16),
              
              // Command
              TextField(
                controller: _commandController,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13),
                maxLines: 3,
                onChanged: (val) {
                  if (_validationError != null) {
                    setState(() { _validationError = null; });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Command to Execute',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: AppTheme.obsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.code, color: AppTheme.neonPurple),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.crimson),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              
              // Icon selection
              Text(
                'Select Icon',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableIcons.entries.map((entry) {
                  final isSelected = _selectedIcon == entry.key;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = entry.key),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.neonCyan.withValues(alpha: 0.2) : AppTheme.obsidian,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.neonCyan : AppTheme.cardBorder,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        color: isSelected ? AppTheme.neonCyan : Colors.white60,
                        size: 24,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: AppTheme.obsidian,
          ),
          onPressed: _save,
          child: const Text('Save Command', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
