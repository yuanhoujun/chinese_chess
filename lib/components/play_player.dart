import 'package:flutter/material.dart';

import '../driver/player_driver.dart';
import '../generated/l10n.dart';
import '../widgets/game_wrapper.dart';
import '../models/game_manager.dart';
import '../widgets/tab_card.dart';

/// 组合玩家框及对局双方信息框
class PlayPlayer extends StatefulWidget {
  const PlayPlayer({Key? key}) : super(key: key);

  @override
  State<PlayPlayer> createState() => PlayPlayerState();
}

class PlayPlayerState extends State<PlayPlayer> {
  late GameManager gamer;
  int currentTeam = 0;

  @override
  void initState() {
    super.initState();
    GameWrapperState gameWrapper =
        context.findAncestorStateOfType<GameWrapperState>()!;
    gamer = gameWrapper.gamer;
    gamer.playerNotifier.addListener(onChangePlayer);
    gamer.gameNotifier.addListener(onReloadGame);
    gamer.resultNotifier.addListener(onResult);
  }

  @override
  dispose() {
    gamer.playerNotifier.removeListener(onChangePlayer);
    gamer.gameNotifier.removeListener(onReloadGame);
    gamer.resultNotifier.removeListener(onResult);
    super.dispose();
  }

  onResult() {
    setState(() {});
  }

  onReloadGame() {
    if (gamer.gameNotifier.value != 0) return;
    setState(() {});
  }

  onChangePlayer() {
    setState(() {
      currentTeam = gamer.playerNotifier.value;
    });
  }

  Widget switchRobot(int team) {
    if (gamer.hands[team].isUser) {
      return IconButton(
        icon: const Icon(Icons.android),
        tooltip: S.of(context).trusteeship_to_robots,
        onPressed: () {
          changePlayDriver(team, DriverType.robot);
        },
      );
    } else if (gamer.hands[team].isRobot) {
      return IconButton(
        icon: const Icon(
          Icons.android,
          color: Colors.blueAccent,
        ),
        tooltip: S.of(context).cancel_robots,
        onPressed: () {
          changePlayDriver(team, DriverType.user);
        },
      );
    }

    return SizedBox();
  }

  void changePlayDriver(int team, DriverType driverType) {
    setState(() {
      gamer.switchDriver(team, driverType);
    });
  }

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration = BoxDecoration(
        border: Border.all(color: Colors.grey, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(2)));
    return SizedBox(
      width: 229,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.person,
              color: currentTeam == 1 ? Colors.blueAccent : Colors.black12,
            ),
            title: Text(gamer.getPlayer(1).title),
            subtitle: Text(currentTeam == 1 ? S.of(context).thinking : ''),
            trailing: switchRobot(1),
          ),
          const SizedBox(width: 10),
          ListTile(
            leading: Icon(Icons.person,
                color: currentTeam == 0 ? Colors.blueAccent : Colors.black12),
            title: Text(gamer.getPlayer(0).title),
            subtitle: Text(currentTeam == 0 ? S.of(context).thinking : ''),
            trailing: switchRobot(0),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: decoration,
              child: TabCard(
                  titlePadding: EdgeInsets.only(top: 10, bottom: 10),
                  titles: [
                    Text(S.of(context).current_info),
                    Text(S.of(context).manual)
                  ],
                  bodies: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(gamer.manual.event),
                          Text(
                              '${gamer.manual.red} (${gamer.manual.chineseResult}) ${gamer.manual.black}'),
                          Text(gamer.manual.ecco.isEmpty
                              ? ''
                              : '${gamer.manual.opening}(${gamer.manual.ecco})'),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      child: Table(
                        border: null,
                        columnWidths: const {
                          0: IntrinsicColumnWidth(),
                          1: FlexColumnWidth(),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.top,
                        children: [
                          TableRow(children: [
                            Text(S.of(context).the_event),
                            Text(gamer.manual.event)
                          ]),
                          TableRow(children: [
                            Text(S.of(context).the_site),
                            Text(gamer.manual.site)
                          ]),
                          TableRow(children: [
                            Text(S.of(context).the_date),
                            Text(gamer.manual.date)
                          ]),
                          TableRow(children: [
                            Text(S.of(context).the_round),
                            Text(gamer.manual.round)
                          ]),
                          TableRow(children: [
                            Text(S.of(context).the_red),
                            Text('${gamer.manual.redTeam}/${gamer.manual.red}'),
                          ]),
                          TableRow(children: [
                            Text(S.of(context).the_black),
                            Text(
                                '${gamer.manual.blackTeam}/${gamer.manual.black}'),
                          ]),
                        ],
                      ),
                    )
                  ]),
            ),
          )
        ],
      ),
    );
  }
}