import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../providers/server_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class InteractiveShellSheet extends StatefulWidget {
  const InteractiveShellSheet({super.key});

  @override
  State<InteractiveShellSheet> createState() => _InteractiveShellSheetState();
}

class _InteractiveShellSheetState extends State<InteractiveShellSheet> {
  late Terminal _terminal;
  final TerminalController _terminalController = TerminalController();
  SSHSession? _session;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  bool _connecting = true;
  String _error = '';
  bool _ctrlActive = false;
  bool _shiftActive = false;
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    StorageService().getTerminalFontSize().then((size) {
      if (mounted) setState(() => _fontSize = size);
    });
    _initShell();
  }

  void _initShell() async {
    final provider = Provider.of<ServerProvider>(context, listen: false);
    if (provider.status != ConnectionStatus.connected) {
      setState(() {
        _connecting = false;
        _error = 'No connected server to start shell.';
      });
      return;
    }

    try {
      final session = await provider.sshService.startShellSession(width: 80, height: 24);
      _session = session;

      _terminal.onResize = (w, h, pw, ph) {
        session.resizeTerminal(w, h);
      };

      _terminal.onOutput = (data) {
        String modifiedData = data;
        if (_shiftActive) {
          modifiedData = _applyShiftModifier(modifiedData);
        }
        if (_ctrlActive) {
          modifiedData = _applyCtrlModifier(modifiedData);
        }
        if (_ctrlActive || _shiftActive) {
          if (mounted) {
            setState(() {
              _ctrlActive = false;
              _shiftActive = false;
            });
          }
        }
        session.write(utf8.encode(modifiedData));
      };

      _stdoutSub = session.stdout.listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      }, onDone: () {
        if (mounted) {
          _terminal.write('\r\n\x1b[31m[SSH Shell session terminated by remote server]\x1b[0m\r\n');
        }
      });

      _stderrSub = session.stderr.listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Unable to start PTY shell: $e';
        });
      }
    }
  }

  String _applyShiftModifier(String input) {
    if (input.isEmpty) return input;
    return input.toUpperCase();
  }

  String _applyCtrlModifier(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      int charCode = input.codeUnitAt(i);
      if (charCode >= 97 && charCode <= 122) {
        buffer.writeCharCode(charCode - 96);
      } else if (charCode >= 64 && charCode <= 95) {
        buffer.writeCharCode(charCode - 64);
      } else if (charCode == 32) {
        buffer.writeCharCode(0);
      } else if (charCode == 63) {
        buffer.writeCharCode(127);
      } else {
        buffer.writeCharCode(charCode);
      }
    }
    return buffer.toString();
  }

  void _sendShortcut(String sequence) {
    String modifiedData = sequence;
    if (_shiftActive) {
      modifiedData = _applyShiftModifier(modifiedData);
    }
    if (_ctrlActive) {
      modifiedData = _applyCtrlModifier(modifiedData);
    }
    if (_ctrlActive || _shiftActive) {
      if (mounted) {
        setState(() {
          _ctrlActive = false;
          _shiftActive = false;
        });
      }
    }
    if (_session != null) {
      _session!.write(utf8.encode(modifiedData));
    } else {
      _terminal.onOutput?.call(modifiedData);
    }
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.terminal, color: AppTheme.neonCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Terminal: ${provider.activeProfile?.name ?? "SSH Shell"}',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out, color: AppTheme.neonCyan, size: 20),
            tooltip: 'Decrease Font Size',
            onPressed: () {
              if (_fontSize > 10) {
                setState(() => _fontSize -= 1);
                StorageService().setTerminalFontSize(_fontSize);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: AppTheme.neonCyan, size: 20),
            tooltip: 'Increase Font Size',
            onPressed: () {
              if (_fontSize < 24) {
                setState(() => _fontSize += 1);
                StorageService().setTerminalFontSize(_fontSize);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
            tooltip: 'Restart Shell',
            onPressed: () {
              _stdoutSub?.cancel();
              _stderrSub?.cancel();
              _session?.close();
              _terminal = Terminal(maxLines: 10000);
              setState(() {
                _connecting = true;
                _error = '';
              });
              _initShell();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di scorciatoie per tastiera mobile Linux/Terminal
          Container(
            height: 44,
            color: AppTheme.surfaceDark,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                _buildModifierButton('CTRL', _ctrlActive, () => setState(() => _ctrlActive = !_ctrlActive), AppTheme.neonCyan),
                _buildModifierButton('SHIFT', _shiftActive, () => setState(() => _shiftActive = !_shiftActive), AppTheme.neonPurple),
                _buildKeyButton('ESC', '\x1b', AppTheme.amber),
                _buildKeyButton('TAB', '\t', AppTheme.neonPurple),
                _buildKeyButton('Ctrl+C', '\x03', AppTheme.crimson),
                _buildKeyButton('Ctrl+Z', '\x1A', AppTheme.crimson.withValues(alpha: 0.8)),
                _buildKeyButton('↑', '\x1b[A', AppTheme.neonCyan),
                _buildKeyButton('↓', '\x1b[B', AppTheme.neonCyan),
                _buildKeyButton('←', '\x1b[D', AppTheme.neonCyan),
                _buildKeyButton('→', '\x1b[C', AppTheme.neonCyan),
                _buildKeyButton('/', '/', Colors.white),
                _buildKeyButton('-', '-', Colors.white),
                _buildKeyButton('|', '|', Colors.white),
                _buildKeyButton('~', '~', Colors.white),
              ],
            ),
          ),
          const Divider(color: AppTheme.cardBorder, height: 1),

          // Area Terminale vera e propria con colori ANSI e input
          Expanded(
            child: _connecting
                ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 56, color: AppTheme.crimson),
                              const SizedBox(height: 16),
                              Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close Terminal'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TerminalView(
                          _terminal,
                          controller: _terminalController,
                          autofocus: true,
                          textStyle: TerminalStyle.fromTextStyle(
                            GoogleFonts.jetBrainsMono(fontSize: _fontSize),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String label, String sequence, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: AppTheme.obsidian,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _sendShortcut(sequence),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModifierButton(String label, bool active, VoidCallback onTap, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: active ? activeColor : AppTheme.obsidian,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: active ? activeColor : activeColor.withValues(alpha: 0.4),
                width: active ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              active ? '$label ★' : label,
              style: GoogleFonts.outfit(
                color: active ? AppTheme.obsidian : activeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
