import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import '../../ui/pin_pad.dart';
import '../../ui/vault_theme.dart';

/// A screen of PIN steps with a back arrow, shared by the flows below.
class _PinScaffold extends StatelessWidget {
  const _PinScaffold({required this.child, this.onBack});

  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Asks for a password the old way, for vaults made before PINs, whose
/// passwords may have letters.
class _TextStep extends StatefulWidget {
  const _TextStep({super.key, required this.title, required this.onDone, this.error});

  final String title;
  final ValueChanged<String> onDone;
  final String? error;

  @override
  State<_TextStep> createState() => _TextStepState();
}

class _TextStepState extends State<_TextStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          obscureText: true,
          autofocus: true,
          onSubmitted: widget.onDone,
        ),
        const SizedBox(height: 8),
        Text(widget.error ?? '', style: TextStyle(color: c.danger)),
        const Spacer(),
        FilledButton(
          onPressed: () => widget.onDone(_controller.text),
          child: const Text('Next'),
        ),
      ],
    );
  }
}

enum _ChangeStep { current, next, confirm, working }

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  _ChangeStep _step = _ChangeStep.current;
  String _new = '';
  String? _error;
  int _errors = 0;

  void _fail(String message) => setState(() {
        _error = message;
        _errors++;
      });

  Future<void> _apply(String confirm) async {
    if (confirm != _new) {
      _fail("Those PINs don't match");
      return;
    }
    if (await VaultService.isPasswordTaken(_new)) {
      setState(() => _step = _ChangeStep.next);
      _fail('Another vault uses that PIN');
      return;
    }
    if (!mounted) return;
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final old = state.currentPassword;
    if (vault == null || old == null) return;
    setState(() => _step = _ChangeStep.working);
    final ok = await VaultService.changePassword(vault, old, _new);
    if (!mounted) return;
    if (!ok) {
      setState(() => _step = _ChangeStep.next);
      _fail('Could not change the PIN. Nothing was changed.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    state.lock();
    messenger.showSnackBar(const SnackBar(content: Text('PIN changed. Use the new one from now on.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.currentPassword ?? '';
    final digitsOnly = RegExp(r'^\d+$').hasMatch(current);

    final Widget body = switch (_step) {
      _ChangeStep.current => digitsOnly
          ? PinStep(
              key: const ValueKey('current'),
              title: 'Current PIN',
              error: _error,
              errorCount: _errors,
              autoSubmitLength: current.length,
              onDone: (pin) => pin == current
                  ? setState(() {
                      _step = _ChangeStep.next;
                      _error = null;
                    })
                  : _fail('That is not the PIN of this vault'),
            )
          : _TextStep(
              key: const ValueKey('current-text'),
              title: 'Current password',
              error: _error,
              onDone: (text) => text == current
                  ? setState(() {
                      _step = _ChangeStep.next;
                      _error = null;
                    })
                  : _fail('That is not the password of this vault'),
            ),
      _ChangeStep.next => PinStep(
          key: const ValueKey('next'),
          title: 'New PIN',
          subtitle: '6 to 12 digits',
          error: _error,
          errorCount: _errors,
          onDone: (pin) => setState(() {
            _new = pin;
            _error = null;
            _step = _ChangeStep.confirm;
          }),
        ),
      _ChangeStep.confirm => PinStep(
          key: const ValueKey('confirm'),
          title: 'Type it again',
          autoSubmitLength: _new.length,
          error: _error,
          errorCount: _errors,
          onDone: _apply,
        ),
      _ChangeStep.working => const Center(
          key: ValueKey('working'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Locking everything with the new PIN'),
            ],
          ),
        ),
    };

    return PopScope(
      canPop: _step != _ChangeStep.working,
      child: _PinScaffold(child: body),
    );
  }
}

enum _NewStep { name, pin, confirm }

/// Makes another vault with its own PIN, for example a decoy to show others.
class NewVaultScreen extends StatefulWidget {
  const NewVaultScreen({super.key});

  @override
  State<NewVaultScreen> createState() => _NewVaultScreenState();
}

class _NewVaultScreenState extends State<NewVaultScreen> {
  _NewStep _step = _NewStep.name;
  final _name = TextEditingController();
  String _pin = '';
  String? _error;
  int _errors = 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(String confirm) async {
    if (confirm != _pin) {
      setState(() {
        _error = "Those PINs don't match";
        _errors++;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      if (await VaultService.isPasswordTaken(_pin)) {
        setState(() {
          _busy = false;
          _step = _NewStep.pin;
          _error = 'Another vault uses that PIN';
          _errors++;
        });
        return;
      }
      if (!mounted) return;
      await VaultService.createVault(
        _pin,
        name: _name.text.trim(),
        createdByVaultId: context.read<AppState>().currentVault?.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not make the vault';
        _errors++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.vault;
    final Widget body = switch (_step) {
      _NewStep.name => Column(
          key: const ValueKey('name'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New vault', style: text.displaySmall),
            const SizedBox(height: 10),
            Text('It opens with its own PIN and shows only what you put in it.',
                style: text.bodyLarge!.copyWith(color: c.muted)),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Name, such as Work'),
              onChanged: (_) => setState(() {}),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () => setState(() => _step = _NewStep.pin),
              child: const Text('Next'),
            ),
          ],
        ),
      _NewStep.pin => PinStep(
          key: const ValueKey('pin'),
          title: 'PIN for ${_name.text.trim()}',
          subtitle: '6 to 12 digits, different from your other vaults',
          error: _error,
          errorCount: _errors,
          onDone: (pin) => setState(() {
            _pin = pin;
            _error = null;
            _step = _NewStep.confirm;
          }),
        ),
      _NewStep.confirm => PinStep(
          key: const ValueKey('confirm'),
          title: 'Type it again',
          autoSubmitLength: _pin.length,
          error: _error,
          errorCount: _errors,
          busy: _busy,
          onDone: _create,
        ),
    };

    return PopScope(
      canPop: _step == _NewStep.name,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _step = _step == _NewStep.confirm ? _NewStep.pin : _NewStep.name);
      },
      child: _PinScaffold(
        onBack: _step == _NewStep.name
            ? null
            : () => setState(() => _step = _step == _NewStep.confirm ? _NewStep.pin : _NewStep.name),
        child: body,
      ),
    );
  }
}
