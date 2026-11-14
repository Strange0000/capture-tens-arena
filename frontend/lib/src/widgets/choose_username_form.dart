import 'dart:async';

import 'package:flutter/material.dart';

import '../services/username_rules.dart';
import '../theme.dart';

/// "Choose your username" form — shown once, at first game entry, never at
/// login (PR-C). The player cannot skip it: every later feature (friends,
/// invites, ranked) needs a unique name, and the name is permanent for
/// this round (no rename yet).
///
/// It is presented as a full screen (see ChooseUsernameScreen), NOT as a
/// floating dialog overlay. In the overlay the web text-input bridge never
/// delivered keystrokes to the field's controller — the live debug readout
/// stayed txt="" while the box showed the typed name — so no name could
/// ever be typed. A normal screen works (the lobby search proves it).
///
/// The form takes its backend calls as callbacks so it can be widget
/// tested without a live server (see test/choose_username_form_test.dart).
class ChooseUsernameForm extends StatefulWidget {
  const ChooseUsernameForm({
    super.key,
    required this.currentUsername,
    required this.isGuest,
    required this.onCheckAvailability,
    required this.onClaim,
  });

  /// The name the account has right now (a GuestXXXXXX name for guests, a
  /// Google profile name for new Google accounts). Used only to suggest a
  /// starting point — a guest name is reserved, so guests start blank.
  final String? currentUsername;

  /// True for guest accounts (their current name is a temporary Guest name).
  final bool isGuest;

  /// Live availability check. Returns the server's answer
  /// ({available, reason, message, suggestions}) or null when the check
  /// itself failed (no network, server down).
  final Future<Map<String, dynamic>?> Function(String username) onCheckAvailability;

  /// Claims the name. Throws a plain-words Exception on failure.
  final Future<void> Function(String username) onClaim;

  @override
  State<ChooseUsernameForm> createState() => _ChooseUsernameFormState();
}

enum _NameState { idle, checking, available, taken, invalid }

class _ChooseUsernameFormState extends State<ChooseUsernameForm> {
  late final TextEditingController _controller;
  Timer? _debounce;
  _NameState _state = _NameState.idle;
  String? _message;
  List<String> _suggestions = [];
  bool _claiming = false;
  String? _claimError;

  @override
  void initState() {
    super.initState();
    // Suggest a valid version of the current name when there is one — a
    // Google profile name like "Sumit Jaiswal" becomes "SumitJaiswal".
    // Guests keep a blank field: their Guest name is reserved anyway.
    final suggested = widget.isGuest
        ? ''
        : sanitizeUsernameBase(widget.currentUsername ?? '');
    _controller = TextEditingController(text: suggested);
    if (suggested.isNotEmpty) _scheduleCheck();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _claimError = null;
    final problem = validateUsernameLocally(value);
    if (problem != null) {
      _debounce?.cancel();
      setState(() {
        _state = _NameState.invalid;
        _message = problem;
        _suggestions = [];
      });
      return;
    }
    _scheduleCheck();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    setState(() => _state = _NameState.checking);
    _debounce = Timer(const Duration(milliseconds: 500), _checkAvailability);
  }

  Future<void> _checkAvailability() async {
    final name = _controller.text.trim();
    if (validateUsernameLocally(name) != null) return;
    final answer = await widget.onCheckAvailability(name);
    if (!mounted) return;
    // The player may have typed on while the check was in flight.
    if (_controller.text.trim() != name) return;
    if (answer == null) {
      setState(() {
        _state = _NameState.invalid;
        _message = 'Could not check that name. Check your connection and try again.';
        _suggestions = [];
      });
      return;
    }
    final available = answer['available'] as bool? ?? false;
    final suggestions = (answer['suggestions'] as List?)?.whereType<String>().toList() ?? [];
    setState(() {
      _state = available ? _NameState.available : _NameState.taken;
      _message = answer['message'] as String? ??
          (available ? 'That name is free.' : 'That name is already taken.');
      _suggestions = suggestions;
    });
  }

  Future<void> _claim() async {
    if (_state != _NameState.available || _claiming) return;
    setState(() {
      _claiming = true;
      _claimError = null;
    });
    try {
      await widget.onClaim(_controller.text.trim());
      // On success AppState clears usernameChoiceRequested, which removes
      // this screen — nothing more to do here.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _claimError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Color get _messageColor {
    switch (_state) {
      case _NameState.available:
        return ArenaColors.emerald;
      case _NameState.taken:
      case _NameState.invalid:
        return Colors.redAccent;
      case _NameState.checking:
      case _NameState.idle:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canClaim = _state == _NameState.available && !_claiming;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ArenaColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ArenaColors.gold.withValues(alpha: 0.5), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isGuest
                    ? 'Pick a name other players will see. Your temporary name is ${widget.currentUsername ?? 'Guest'} — it will be replaced.'
                    : 'Pick a name other players will see. You can only pick once, so choose one you like.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 24,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'e.g. Arjun_99',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  counterText: '',
                  filled: true,
                  fillColor: ArenaColors.panelLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ArenaColors.gold.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ArenaColors.gold, width: 2),
                  ),
                  suffixIcon: _state == _NameState.checking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ArenaColors.gold),
                          ),
                        )
                      : _state == _NameState.available
                          ? const Icon(Icons.check_circle, color: ArenaColors.emerald)
                          : _state == _NameState.taken || _state == _NameState.invalid
                              ? const Icon(Icons.error, color: Colors.redAccent)
                              : null,
                ),
                onChanged: _onChanged,
                onSubmitted: (_) => _claim(),
              ),
              const SizedBox(height: 8),
              const Text(
                '3–24 characters · letters, numbers and _ only · must start with a letter',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(color: _messageColor, fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Try one of these:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: _suggestions
                      .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(color: ArenaColors.gold)),
                            backgroundColor: ArenaColors.panelLight,
                            side: BorderSide(color: ArenaColors.gold.withValues(alpha: 0.4)),
                            onPressed: () {
                              _controller.text = s;
                              _onChanged(s);
                            },
                          ))
                      .toList(),
                ),
              ],
              if (_claimError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _claimError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: canClaim ? _claim : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArenaColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _claiming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Save my username',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
