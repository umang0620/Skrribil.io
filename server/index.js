const express = require("express");
const http = require("http");
const app = express();
const port = process.env.PORT || 3000;
const mongoose = require("mongoose");
const Room = require("./models/Room");
var server = http.createServer(app);
const getWord = require("./api/getWord");


io = require('socket.io')(server, {
  cors:{
      origin:"*"
  },
});

app.use(express.json());

const Db ='mongodb+srv://umang:terabaap%4012345@cluster0.4at7uhi.mongodb.net/?retryWrites=true&w=majority';

mongoose.connect(Db)
.then(()=>console.log("Database Is connected"))
.catch((err)=>console.log(err +"error in database connection"))

io.on('connection', (socket) => {
    console.log("User connected"),
    socket.on('create-game',async({nickname, name, occupancy, maxRounds})=>{
    try{
        const existingRoom = await Room.findOne({name});
        if(existingRoom)
        {
          socket.emit('notCorrectGame','Room with that name already exists !');
          return;
        }
        let room = new Room();
        const word = getWord();
        room.word = word;
        room.name = name;
        room.occupancy = occupancy;
        room.maxRounds = maxRounds;

        let player = {
            socketId: socket.id,
            nickname,
            isPartyLeader: true,
        }
        room.players.push(player);
        room  = await room.save();
        socket.join(name);
        io.to(name).emit('updateRoom',Room,ack=>{});
    }
    catch(err)
    {
     console.log(err);
    }
    }),

    //JOIN GAME CALLBACK
    socket.on('join-game',async({nickname, name })=>
    {
    try{
    let room = await Room.findOne({name});
    if(!room)
    {
        socket.emit('notCorrectGame','Please Enter valid Room name!');
        return;

    }
    if(room.isJoin)
    {
        let player = {
            socketId: socket.id,
            nickname
        }
        room.players.push(player);
        socket.join(name);

        if(room.players.length === room.occupancy)
        {
               room.isJoin = false;
        }
        room.turn = room.players[room.turnIndex];
        room = await room.save();
        io.to(name).emit('updateRoom',room,ack=>{});
    }
    else{
        socket.emit('notCorrectGame','The game is in progress, plz try later!');
    }
    }
    catch(err)
    {
    console.log(err);
    }
    })

    //White board scokets
    socket.on('paint',({details, roomName})=>
    {
       io.to(roomName).emit('points',{details: details});
      // socket.broadcast.emit('points', )
    })

   //color socket
    socket.on('color-change',({color, roomName}) =>
    {
      io.to(roomName).emit('color-change',color);
    })

    //Stroke Scoket
    socket.on('stroke-width',({value, roomName}) => {
       io.to(roomName).emit('stroke-width', value);
    })

})


server.listen(port,()=>{
    console.log("Server started and running on portnumber" + port);
})


