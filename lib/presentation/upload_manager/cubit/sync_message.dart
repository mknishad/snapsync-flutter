import 'package:equatable/equatable.dart';

/// A one-off message for a snackbar. Delivered on `SyncCubit.messages`, not
/// kept in state, so it is shown once.
class SyncMessage extends Equatable {
  const SyncMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  List<Object?> get props => [text, isError];
}
