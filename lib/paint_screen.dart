import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skribbl/models/touch_points.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'models/my_custom_painter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';



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


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    connect();
  }
  void connect(){
    print("ASDASD");
    socket = IO.io("http://192.168.1.6:3000", <String, dynamic>{
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
      ;
      socket.on('updateRoom', (roomData) {
           setState(() {
             dataofRoom = roomData;
           });
           if(roomData['isJoin'] != true)
             {
               //start timmer
             }
      });
      socket.on('points', (point) {
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

    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    //
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
       backgroundColor: Colors.white,
      body: Stack(
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
                    print(details.localPosition.dx);
                    socket.emit('paint',{
                      'details':{
                        'dx':details.localPosition.dx,
                        'dy': details.localPosition.dy,
                      },
                      'roomName': widget.data['name'],
                    });

                  },
                  onPanStart: (details){
                    print(details.localPosition.dx);
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
                   IconButton(onPressed: (){}, icon:Icon(Icons.layers_clear,color: selectedColor,)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
