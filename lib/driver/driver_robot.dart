

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/chess_rule.dart';
import '../models/chess_item.dart';
import '../models/chess_fen.dart';
import '../models/engine.dart';
import '../models/player.dart';
import '../models/chess_pos.dart';

import 'player_driver.dart';

class DriverRobot extends PlayerDriver{
  DriverRobot(Player player) : super(player);
  Completer<String> requestMove;
  bool isCleared = true;

  Future<bool> tryDraw(){
    return Future.value(true);
  }

  @override
  Future<String> move() {
    requestMove = Completer<String>();

    // 网页版用不了引擎
    Future.delayed(Duration(seconds: 1)).then((value) {
      if(Engine.isSupportEngine) {
        getMoveFromEngine();
      }else {
        getMove();
      }
    });

    return requestMove.future;
  }
  getMoveFromEngine() async{
    player.manager.startEngine().then((v){
      if(v){
        player.manager.engine.requestMove(player.manager.fenStr, depth: 10)
            .then(onEngineMessage);
      }else{
        getMove();
      }
    });
  }

  onEngineMessage(String message){
    List<String> parts = message.split(' ');
    switch (parts[0]) {
      case 'ucciok':
        break;
      case 'nobestmove':
      case 'isbusy':
        if(!isCleared){
          isCleared=true;
          return;
        }
        if (!requestMove.isCompleted) {
          player.manager.engine.removeListener(onEngineMessage);
          getMove();
        }
        break;
      case 'bestmove':
        if(!isCleared){
          isCleared=true;
          return;
        }
        player.manager.engine.removeListener(onEngineMessage);
        completeMove(parts[1]);
        break;
      case 'info':
        break;
      case 'id':
      case 'option':
      default:
        return;
    }
  }

  getMove() async{
    print('thinking');
    int team = player.team == 'r'?0:1;
    List<String> moves = await getAbleMoves(player.manager.fen, team);
    if(moves.length < 1 ){
      completeMove('giveup');
      return;
    }
    //print(moves);
    await Future.delayed(Duration(milliseconds: 100));
    Map<String, int> moveGroups = await checkMoves(player.manager.fen, team, moves);
    //print(moveGroups);
    await Future.delayed(Duration(milliseconds: 100));

    String move = await pickMove(moveGroups);
    //print(move);
    completeMove(move);
  }


  /// 获取可以走的着法
  Future<List<String>> getAbleMoves(ChessFen fen, int team) async{
    List<String> moves = [];
    List<ChessItem> items = fen.getAll();
    items.forEach((item) {
      if(item.team == team) {
        List<String> curMoves =
            ChessRule(fen).movePoints(item.position).map<String>((toPos) => item
                .position.toCode() + toPos).toList();

        curMoves = curMoves.where((move) {
          ChessRule rule = ChessRule(fen.copy());
          rule.fen.move(move);
          if(rule.isKingMeet(team)){
            return false;
          }
          if(rule.isCheck(team)){
            return false;
          }
          return true;
        }).toList();
        if(curMoves.length > 0){
          moves += curMoves;
        }
      }
    });

    return moves;
  }

  /// todo 检查着法优势 吃子（被吃子是否有根以及与本子权重），躲吃，生根，将军，叫杀 将着法按权重分组
  Future<Map<String, int>> checkMoves(ChessFen fen, int team, List<String> moves) async{
    // 着法加分
    List<int> weights = [
      49, // 0.将军
      99, // 1.叫杀
      199, // 2.挡将，挡杀
      9, // 3.捉 这四项根据子力价值倍乘
      19, // 4.保
      19, // 5.吃
      9, // 6.躲
      0, // 7.闲 进 退
    ];
    Map<String, int> moveWeight = {};

    ChessRule rule = ChessRule(fen);

    int enemyTeam = team == 0 ? 1 : 0;
    // 被将军的局面，生成的都是挡着
    if(rule.isCheck(team)){

      // 计算挡着后果
      moves.forEach((move) {
        ChessRule nRule = ChessRule(fen.copy());
        nRule.fen.move(move);

        // 走着后还能不能被将
        bool canCheck = nRule.teamCanCheck(enemyTeam);
        if(!canCheck){
          moveWeight[move] = weights[2];
        }else{
          moveWeight[move] = weights[2] * 3;
        }
      });
    }else {

      moves.forEach((move) {
        moveWeight[move] = 0;
        ChessPos fromPos = ChessPos.fromCode(move.substring(0, 2));
        ChessPos toPos = ChessPos.fromCode(move.substring(2, 4));

        String chess = fen[fromPos.y][fromPos.x];
        String toChess = fen[toPos.y][toPos.x];
        if (toChess != '0') {
          int toRootCount = rule.rootCount(toPos, enemyTeam);
          int wPower = rule.getChessWeight(toPos);

          // 被吃子有根，则要判断双方子力价值才吃
          if(toRootCount > 0){
            wPower -= rule.getChessWeight(fromPos);
          }
          moveWeight[move] += weights[5] * wPower;
        }
        int rootCount = rule.rootCount(fromPos, team);
        int eRootCount = rule.rootCount(fromPos, enemyTeam);

        // 躲吃
        if(rootCount < 1 && eRootCount > 0){
          moveWeight[move] += weights[6] * rule.getChessWeight(fromPos);
        }else if(rootCount < eRootCount){
          moveWeight[move] += weights[6] * (rule.getChessWeight(fromPos) - rule.getChessWeight(toPos));
        }

        // 开局兵不挡马路不动兵
        int chessCount = rule.fen.getAllChr().length;
        if(chessCount > 28) {
          if (chess == 'p') {
            if(fen[fromPos.y+1][fromPos.x] == 'n'){
              moveWeight[move] += 9;
            }
          } else if (chess == 'P') {
            if(fen[fromPos.y-1][fromPos.x] == 'N'){
              moveWeight[move] += 9;
            }
          }

          // 开局先动马炮
          if(['c','C','n','N'].contains(chess)){
            moveWeight[move] += 9;
          }

        }
        if(chessCount > 20) {
          // 车马炮在原位的优先动
          if ((chess == 'C' && fromPos.y == 2 && (fromPos.x == 1 || fromPos.x == 7)) ||
              (chess == 'c' && fromPos.y == 7 && (fromPos.x == 1 || fromPos.x == 7))) {
            moveWeight[move] += 19;
          }
          if ((chess == 'N' && fromPos.y == 0) ||(chess == 'n' && fromPos.y == 9)) {
            moveWeight[move] += 19;
          }
          if ((chess == 'R' && fromPos.y == 0) ||(chess == 'r' && fromPos.y == 9)) {
            moveWeight[move] += 9;
          }
        }

        // 马往前跳权重增加
        if((chess == 'n' && toPos.y < fromPos.y) || (chess == 'N' && toPos.y > fromPos.y)){
          moveWeight[move] += 9;
        }

        // 马在原位不动车
        if((chess == 'r' && fromPos.y == 9) || (chess == 'R' && fromPos.y == 0)){
          ChessPos nPos = rule.fen.find(chess == 'R'?'N':'n');
          if(fromPos.x == 0 ){
            if(nPos.x == 1 && nPos.y == fromPos.y){
              moveWeight[move] -= rule.getChessWeight(nPos);
            }
          }else if(fromPos.x == 8){
            if(nPos.x == 7 && nPos.y == fromPos.y){
              moveWeight[move] -= rule.getChessWeight(nPos);
            }
          }
        }

        ChessRule mRule = ChessRule(fen.copy());
        mRule.fen.move(move);

        // 走招后要被将军
        if(rule.teamCanCheck(enemyTeam)){

          List<String> checkMoves = rule.getCheckMoves(enemyTeam);
          checkMoves.forEach((eMove) {
            ChessRule eRule = ChessRule(mRule.fen.copy());
            eRule.fen.move(eMove);
            // 不能应将，就是杀招
            if(eRule.canParryKill(team)){
              print('$move 要被将军');
              moveWeight[move] -= weights[0];
            }else{
              print('$move 有杀招');
              moveWeight[move] -= weights[1];
            }
          });
        }else{
          rootCount = rule.rootCount(toPos, team);
          eRootCount = rule.rootCount(toPos, enemyTeam);
          if((rootCount == 0 && eRootCount > 0) || rootCount < eRootCount){
            moveWeight[move] -= rule.getChessWeight(toPos);
          }

          // 炮震老将
          if(chess == 'c' || chess == 'C'){

          }

          // 捉子优先

        }
      });
    }
    int minWeight = 0;
    moveWeight.forEach((key, value) {
      if(minWeight > value)minWeight = value;
    });

    if(minWeight < 0){
      moveWeight.updateAll((key, value) => value - minWeight);
    }

    print(moveWeight);

    return moveWeight;
  }

  /// todo 从分组好的招法中随机筛选一个
  Future<String> pickMove(Map<String, int> groups) async{
    int totalSum = 0;
    groups.values.forEach((wgt) {wgt+=1;if(wgt<0)wgt = 0; totalSum += wgt;});

    Random random = Random(DateTime
        .now()
        .millisecondsSinceEpoch);

    double rand = random.nextDouble() * totalSum;
    int curSum = 0;
    String move = '';
    for(String key in groups.keys){
      move = key;
      curSum += groups[key];
      if(curSum > rand){
        break;
      }
    }

    return move;
  }

  @override
  Future<String> ponder() {
    // TODO: implement ponder
    throw UnimplementedError();
  }

  @override
  completeMove(String move) async{
    player.onMove(move).then((value){
      requestMove.complete(move);
    });
  }

  @override
  Future<bool> tryRetract() {
    // TODO: implement tryRetract
    throw UnimplementedError();
  }
}