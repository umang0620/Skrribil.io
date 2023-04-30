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
        console.log(room);
        io.to(name).emit('updateRoom',room);
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
          // console.log("wrong room name");
        return;

    }
     console.log(room);
    if(room.isJoin)
    {
     // console.log("2");
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
        room = await
        room.save();
        console.log(room);
        io.to(name).emit('updateRoom',room);
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

socket.on('msg', async (data) => {
        console.log("in msg event");
        console.log(data.word);
        try{
          if(data.msg === data.word)
           {
            let room = await Room.find({name: data.roomName});
            let userPlayer = room[0].players.filter(
              (player) => player.nickname === data.username
            )
            if(data.timeTaken !== 0)
            {
               userPlayer[0].points += Math.round((200/ data.timeTaken) * 10);
            }
            room = await room[0].save();
            io.to(data.roomName).emit('msg', {
                username: data.username,
                msg: 'Gussed it!',
                guessedUserCtr: data.guessedUserCtr + 1,
            })
            socket.emit('closeInput', "");
          }else{
            io.to(data.roomName).emit('msg',{
                    username: data.username,
                    msg: data.msg,
                    guessedUserCtr: data.guessedUserCtr,
                    })
          }
        }
        catch(err)
        {
        console.log("in catch block",err);
        }
})
socket.on('change-turn', async(name) =>
{
    try{
    let room = await Room.findOne({name});
    let idx = room.turnIndex;
    if(idx +1 === room.players.length){
       room.currentRound +=1;
    }
    if(room.currentRound <= room.maxRounds){
         const word = getWord();
         room.word = word;
         room.turnIndex = (idx+1) % room.players.length;
         room.turn = room.players[room.turnIndex];
         room = await room.save();
         io.to(name).emit('change-turn', room);
    }else{
        console.log(room.player);
        io.to(name).emit('show-leaderboard', room.players);
    }
    }catch(err)
    {
    console.log(err);
    }
})
 socket.on('updateScore', async (name) => {
        try {
            const room = await Room.findOne({name});
            io.to(name).emit('updateScore', room);
        } catch(err) {
            console.log(err);
        }
    })
    //White board scokets
    socket.on('paint',({details, roomName})=>
    {
    if(details != null)
    {
   // io.emit('points',{details: details});
     io.to(roomName).emit('points',{details: details});
    }
    //   console.log(details);
    })

   //color socket
    socket.on('color-change',({color, roomName}) =>
    {
       if(color != null)
      {
        // console.log(color,roomName);
         io.to(roomName).emit('color-change',color);
      }
     // io.emit('color-change',color);
    })

   // Stroke Scoket
    socket.on('stroke-width',({value, roomName}) => {
       if(value != null)
       {
          // console.log(value,roomName);
           io.to(roomName).emit('stroke-width', value);
       }
//       io.to(roomName).emit('stroke-width', value);
//        io.emit('stroke-width', value);
    })

    // Clear Screen
    socket.on('clean-screen', (roomName) => {
        io.to(roomName).emit('clear-screen', '');
    })

    socket.on('disconnect', async()=>{
    console.log("your are in disconnect");
 let room  = await Room.findOne({"players.socketId": socket.id});
//  console.log(room);
    try {
       // let room  = await Room.findOne({"players.socketId": socket.id});
         console.log(room);
        for(let i=0; i < room.players.length; i++ )
        {
            if(room.players[i].socketId === socket.id)
            {
                    room.players.splice(i, 1);
                    break;
            }
         }
         room = await room.save();
         if(room.players.length === 1)
         {
               console.log("in if brodcast")
              io.to(room.name).emit('show-leaderboard', room.players);
         }
         else{
         console.log("in else brodcast")
          io.to(room.name).emit('user-disconnected', room);
         }
    }catch(err){
         console.log(err);
    }
    })
})


server.listen(port,()=>{
    console.log("Server started and running on portnumber" + port);
})


