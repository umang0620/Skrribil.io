import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skribbl/models/touch_points.dart';
import 'package:skribbl/sidebar/player_scoreboard_drawer.dart';
import 'package:skribbl/waiting_lobby_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'final_leaderboard.dart';
import 'home_screen.dart';
import 'models/my_custom_painter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:convert';



class PaintScreen extends StatefulWidget {
  final Map<String,String> data;
  final String? screenFrom;

  const PaintScreen({Key? key,required this.data ,required this.screenFrom}) : super(key: key);

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  Map dataofRoom = {};
  List<TouchPoints> points = [];
  late IO.Socket socket;
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColor = Colors.black;
  double opacity = 1;
  double strokeWidth = 2;
  List<Widget> textBlankWidget = [];
  ScrollController _scrollController = ScrollController();
  TextEditingController controller = TextEditingController();
  List<Map> messages = [];
  int guessedUserCtr = 0;
  int _start = 60;
  late Timer _timer;
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map> scoreboard = [];
  bool isTextInputReadOnly = false;
  int maxPoints = 0;
  String winner = "";
  bool isShowFinalLeaderboard = false;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    connect();
  }

  void startTimer() {
    const oneSec = const Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer time) {
      if (_start == 0) {
        socket.emit('change-turn', dataofRoom['name']);
        setState(() {
          _timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }


  void renderTextBlank(String text){
         textBlankWidget.clear();
         for(int i=0; i < text.length; i++)
           {
             textBlankWidget.add(Text('_',style: TextStyle(fontSize: 30)));
           }
  }


  void connect(){
    print("ASDASD");
    socket = IO.io("http://192.168.1.11:3000", <String, dynamic>{
      'transports':['websocket'],
      'autoConnect': true,
    });
    socket.connect();
    if(widget.screenFrom == 'createRoom')
      {
        socket.emit('create-game',widget.data);
      }
    else{
      socket.emit('join-game',widget.data);
    }
    socket.onConnect((data) {
      print("Connected");
      socket.on('updateRoom', (roomData) {
          print(roomData['word']);
           setState(() {
             renderTextBlank(roomData['word']);
             dataofRoom = roomData;
           });
           if(roomData['isJoin'] != true)
             {
              startTimer();
             }
           scoreboard.clear();
          for (int i = 0; i < roomData['players'].length; i++) {
            setState(() {
              scoreboard.add({
                'username': roomData['players'][i]['nickname'],
                'points': roomData['players'][i]['points'].toString()
              });
            });
          }
      });

      socket.on(
          'notCorrectGame',
              (data) => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen()),
                  (route) => false));

      socket.on('points', (point) {
       // print(point);
        if (point['details'] != null) {

          setState(() {
            points.add(TouchPoints(
                points: Offset((point['details']['dx']).toDouble(),
                    (point['details']['dy']).toDouble()),
                paint: Paint()
                  ..strokeCap = strokeType
                  ..isAntiAlias = true
                  ..color = selectedColor.withOpacity(opacity)
                  ..strokeWidth = strokeWidth
            ));
          });
        }
      });
      socket.on('msg',(msgData){
        print(msgData);
        setState(() {
          messages.add(msgData);
          guessedUserCtr = msgData['guessedUserCtr'];
        });
        if (guessedUserCtr == dataofRoom['players'].length - 1) {
          socket.emit('change-turn', dataofRoom['name']);
        }
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 65,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut);

      });

      socket.on('change-turn', (data){
        String oldWord = dataofRoom['word'];
        showDialog(context: context, builder:(context){
          Future.delayed(Duration(seconds: 3), (){
            setState(() {
              dataofRoom = data;
              renderTextBlank(data['word']);
              isTextInputReadOnly = false;
              guessedUserCtr = 0;
              _start = 60;
              points.clear();
            });
            Navigator.of(context).pop();
            _timer.cancel();
            startTimer();
          });
          return AlertDialog(
              title: Center(child: Text('Word was $oldWord'),));
        });
      });

      socket.on('updateScore', (roomData) {
        scoreboard.clear();
        for (int i = 0; i < roomData['players'].length; i++) {
          setState(() {
            scoreboard.add({
              'username': roomData['players'][i]['nickname'],
              'points': roomData['players'][i]['points'].toString()
            });
          });
        }
      });

      socket.on('show-leaderboard',(roomPlayers){
        scoreboard.clear();
        for (int i = 0; i < roomPlayers.length; i++) {
          setState(() {
            scoreboard.add({
              'username': roomPlayers[i]['nickname'],
              'points': roomPlayers[i]['points'].toString()
            });
            print(scoreboard);
            print("gffffffffffffffffffffffffff");
            print(maxPoints);
            print("gffffffffffffffffffffffffff");
            print(int.parse(scoreboard[i]['points']));
          });

          if (maxPoints < int.parse(scoreboard[i]['points'])) {
             winner = scoreboard[i]['username'];
            maxPoints = int.parse(scoreboard[i]['points']);
          }
          else if (int.parse(scoreboard[i]['points']) == 0)
            {
              winner = scoreboard[i]['username'];
              maxPoints = int.parse(scoreboard[i]['points']);
            }
        }
        setState(() {
          _timer.cancel();
          isShowFinalLeaderboard = true;
        });
      });

      socket.on('color-change', (colorString) async {
        int value = await int.parse(colorString, radix: 16);
       Color otherColor = await Color(value);
       setState(() async {
           selectedColor = await otherColor;
        });
      });

      socket.on('stroke-width', (value) {
        setState(() {
          strokeWidth = value.toDouble();
        });
      });

      socket.on('clear-screen', (data) {
        setState(() {
          points.clear();
        });
      });

      socket.on('closeInput', (_) {
        socket.emit('updateScore', widget.data['name']);
        setState(() {
          isTextInputReadOnly = true;
        });
      });

      socket.on('user-disconnected', (data) {
        scoreboard.clear();
        print(data);
        for (int i = 0; i < data['players'].length; i++) {
          setState(() {
            scoreboard.add({
              'username': data['players'][i]['nickname'],
              'points': data['players'][i]['points'].toString()
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    socket.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    void selectColor()
    {
       showDialog(context: context, builder: (context) => AlertDialog(
         title: const Text("Choose Color"),
         content: SingleChildScrollView(
           child: BlockPicker(
               pickerColor: selectedColor, onColorChanged: (color)  {
             String colorString = color.toString();
             String valueString = colorString.split('(0x')[1].split(')')[0];
             print(colorString);
             print(valueString);
             Map map = {
               'color' : valueString,
               'roomName': dataofRoom['name']
             };
             socket.emit('color-change',map);
           }),
         ),
         actions: [
           TextButton(onPressed: (){
             Navigator.of(context).pop();
              },
               child: Text("Close"))
         ]
       ));
    }
    return Scaffold(
      key:scaffoldKey,
       drawer: PlayerScore(scoreboard),
       backgroundColor: Colors.white,
      // body: Center(child: Text(JsonEncoder().convert(widget.data))),
      body: dataofRoom != null ?
      dataofRoom['isJoin'] != true ?
      !isShowFinalLeaderboard ? Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: width,
                height: height*0.55,
                child: GestureDetector(
                  onPanUpdate: (details){
                   // print(details.localPosition.dx);
                    socket.emit('paint',{
                      'details':{
                        'dx':details.localPosition.dx,
                        'dy': details.localPosition.dy,
                      },
                      'roomName': widget.data['name'],
                    });

                  },
                  onPanStart: (details){
                  //  print(details.localPosition.dx);
                    socket.emit('paint',{
                      'details':{
                           'dx':details.localPosition.dx,
                            'dy': details.localPosition.dy,
                      },
                      'roomName': widget.data['name'],
                    });
                  },
                  onPanEnd: (details){
                    socket.emit('paint',{
                      'details': null,
                      'roomName': widget.data['name'],
                    });

                  },
                  child: SizedBox.expand(
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                       child: RepaintBoundary(
                         child: CustomPaint(
                           size: Size.infinite,
                           painter: MyCustomPainter(pointsList: points),
                         ),
                       ),
                    ),
                  ),
                ),
              ),
              Row(
                 children: [
                    IconButton(onPressed: (){
                      selectColor();
                    }, icon:Icon(Icons.color_lens,color: selectedColor,)),
                   Expanded(child: Slider(
                     min:1.0,
                     max: 10,
                     label:"Strokewidth $strokeWidth",
                     activeColor: selectedColor,
                     value: strokeWidth,
                     onChanged: (double value)
                     {
                       Map map = {
                         'value':value,
                         'roomName': dataofRoom['name']
                       };
                       socket.emit('stroke-width',map);
                     },
                   ),
                   ),
                   IconButton(onPressed: (){
                     socket.emit(
                         'clean-screen', dataofRoom['name']);
                   }, icon:Icon(Icons.layers_clear,color: selectedColor,)),
                ],
              ),
              dataofRoom['turn']['nickname'] != widget.data['nickname'] ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: textBlankWidget,
              ) :
              Center(
                child: Text(dataofRoom['word'],
                  style: TextStyle(fontSize: 30),),),
              // Displaying messages
              Container(
                height: MediaQuery.of(context).size.height*0.3,
                child:ListView.builder(
                  controller: _scrollController,
                    shrinkWrap: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index){
                    var msg = messages[index].values;
                    return ListTile(
                      title: Text(
                        msg.elementAt(0),
                        style: TextStyle(color: Colors.black,fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        msg.elementAt(1),
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                    })
              ),
            ],
          ),
            dataofRoom['turn']['nickname'] != widget.data['nickname'] ? Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                readOnly: isTextInputReadOnly,
                controller: controller,
                onSubmitted: (value){
                  if(value.trim().isNotEmpty)
                    {
                      Map map = {
                        'username':widget.data['nickname'],
                        'msg': value.trim(),
                        'word':dataofRoom['word'],
                        'roomName': widget.data['name'],
                        'guessedUserCtr': guessedUserCtr,
                        'totalTime': 60,
                        'timeTaken': 60 - _start,
                      };
                      socket.emit('msg',map);
                      controller.clear();
                    }
                },
                autocorrect: false,
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:const  BorderSide(color: Colors.transparent),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:const  BorderSide(color: Colors.transparent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    filled: true,
                    fillColor: Color(0xffF5F5FA),
                    hintText: 'Your Guess',
                    hintStyle: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w400)
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
          ) : Container(),
          SafeArea(child: IconButton(icon:Icon(Icons.menu , color: Colors.black,),
            onPressed: () => scaffoldKey.currentState!.openDrawer(),),),
        ],
      ): FinalLeaderboard(scoreboard,winner)
          : WaitingLobbyScreen(lobbyName: dataofRoom['name'],
          noOfPlayers: dataofRoom['players'].length,
          occupancy: dataofRoom['occupancy'],
          players: dataofRoom['players'],)
          : Center(child: CircularProgressIndicator(),),
    floatingActionButton: Container(
      margin: EdgeInsets.only(bottom: 30),
      child: FloatingActionButton(
        onPressed: (){},
        elevation: 7,
        backgroundColor: Colors.white,
        child: Text('$_start',style: TextStyle(color: Colors.black,fontSize: 22),),
      ),
    ),
    );
  }
}
