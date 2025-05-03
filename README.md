# pictionis

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### Next to do 
Fix the line size cursor 
Add rubber
Add fill 




### Notes 

- main.dart: This contains the main entry point and the main app widget.
- drawing_board.dart: Drawing logic and the UI for the drawing board.
- drawing_painter.dart: Custom painting logic.
- colored_line.dart: Define the ColoredLine class.


Don't forget : New dependencies = flutter pub get 


Règles / rules firebase 
```
rules_version = '2';
service cloud.firestore {
 match /databases/{database}/documents {
   // Fonctions utilitaires
   function isAuthenticated() {
     return request.auth != null;
   }
   
   function isRoomMember(roomData) {
     return roomData.players.hasAny([request.auth.uid]);
   }
   
   function isRoomCreator(roomData) {
     return roomData.createdBy == request.auth.uid;
   }
   
   function isJoiningRoom(roomData, newData) {
     let currentPlayers = roomData.players;
     let newPlayers = newData.players;
     return newPlayers.size() <= 5 && 
            newPlayers.hasAll(currentPlayers) && 
            newPlayers.removeAll(currentPlayers).hasOnly([request.auth.uid]);
   }
   
   function isLeavingRoom(roomData, newData) {
     let currentPlayers = roomData.players;
     let newPlayers = newData.players;
     return newPlayers.hasAll(currentPlayers.removeAll([request.auth.uid]));
   }

   // Règles collection user_stats
   match /user_stats/{userId} {
     allow read: if isAuthenticated() && request.auth.uid == userId;
     allow create, update: if isAuthenticated() && request.auth.uid == userId;
   }

   // Règles collection rooms
   match /rooms/{roomId} {
     allow read: if isAuthenticated();
     
     allow create: if isAuthenticated() && 
                  request.resource.data.players.size() <= 5 &&
                  request.resource.data.createdBy == request.auth.uid;
     
     allow update: if isAuthenticated() && (
       isRoomMember(resource.data) ||
       (!isRoomMember(resource.data) &&
        request.resource.data.players.size() <= 5 &&
        isJoiningRoom(resource.data, request.resource.data)) ||
       (isRoomMember(resource.data) &&
        isLeavingRoom(resource.data, request.resource.data))
     );
     
     allow delete: if isAuthenticated() && isRoomCreator(resource.data);

     match /drawing/{drawingId} {
       allow read: if isAuthenticated() && 
                   isRoomMember(get(/databases/$(database)/documents/rooms/$(roomId)).data);
       
       allow create, update: if isAuthenticated() && 
                            isRoomMember(get(/databases/$(database)/documents/rooms/$(roomId)).data) &&
                            isRoomCreator(get(/databases/$(database)/documents/rooms/$(roomId)).data);
       
       allow delete: if isAuthenticated() && 
                    isRoomCreator(get(/databases/$(database)/documents/rooms/$(roomId)).data);
     }

     match /messages/{messageId} {
       allow read: if isAuthenticated() && 
                  isRoomMember(get(/databases/$(database)/documents/rooms/$(roomId)).data);
       
       allow create: if isAuthenticated() && 
                    isRoomMember(get(/databases/$(database)/documents/rooms/$(roomId)).data) &&
                    request.resource.data.senderId == request.auth.uid &&
                    request.resource.data.keys().hasAll(['text', 'senderId', 'senderEmail', 'timestamp']);
     }
   }
 }
}
```
