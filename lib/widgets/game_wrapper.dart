import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../global.dart';
import '../models/game_manager.dart';

class GameWrapper extends StatefulWidget {
  final Widget child;
  final bool isMain;

  const GameWrapper({Key? key, required this.child, this.isMain = false})
      : super(key: key);

  static GameWrapperState of(BuildContext context) {
    return context.findAncestorStateOfType<GameWrapperState>()!;
  }

  @override
  State<GameWrapper> createState() => GameWrapperState();
}

class GameWrapperState extends State<GameWrapper> with WindowListener {
  final GameManager gamer = GameManager();

  @override
  void initState() {
    super.initState();
    if (widget.isMain) {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        windowManager.addListener(this);
      }
    }
  }

  @override
  void dispose() {
    if (widget.isMain) {
      gamer.dispose();
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    logger.info('gamer destroy');
    windowManager.removeListener(this);
    gamer.dispose();
    GameManager.instance.engine?.dispose();
  }

  Future<bool> _willPop() async {
    logger.info('onwillpop');
    final sure = await MyDialog.confirm(
      context.l10n.exitNow,
      buttonText: context.l10n.yesExit,
      cancelText: context.l10n.dontExit,
    );

    if (sure ?? false) {
      logger.info('gamer destroy');
      gamer.dispose();
      //gamer = null;
      await Future.delayed(const Duration(milliseconds: 200));
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    if (size.width < 541) {
      gamer.scale = (size.width - 20) / 521;
    } else {
      gamer.scale = 1;
    }
    return WillPopScope(
      onWillPop: widget.isMain ? _willPop : null,
      child: widget.child,
    );
  }
}
