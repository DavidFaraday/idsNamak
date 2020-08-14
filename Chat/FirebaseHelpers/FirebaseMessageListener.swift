//
//  FirebaseMessageListener.swift
//  Chat
//
//  Created by David Kababyan on 14/08/2020.
//  Copyright © 2020 David Kababyan. All rights reserved.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift

class FirebaseMessageListener {
    
    static let shared = FirebaseMessageListener()
    var newChatListener: ListenerRegistration!
    var updatedChatListener: ListenerRegistration!

    private init() {}
    
    func listenForNewChats(_ documentId: String, collectionId: String, lastMessageDate: Date) {
        
        newChatListener = FirebaseReference(.Messages).document(documentId).collection(collectionId).whereField(kDATE, isGreaterThan: lastMessageDate).addSnapshotListener({ (querySnapshot, error) in
            
            guard let snapshot = querySnapshot else { return }
            
            for change in snapshot.documentChanges {
                
                if change.type == .added {
                    let result = Result {
                        try? change.document.data(as: LocalMessage.self)
                    }
                    
                    switch result {
                    case .success(let messageObject):
                        if let message = messageObject {
                            RealmManager.shared.saveToRealm(message)
                        } else {
                            print("Document does not exist chat")
                        }
                    case .failure(let error):
                        print("Error decoding local message: \(error)")
                    }
                }
            }
        })
    }

    
    func checkForOldChats(_ documentId: String, collectionId: String) {
        
        FirebaseReference(.Messages).document(documentId).collection(collectionId).getDocuments { (querySnapshot, error) in

            guard let documents = querySnapshot?.documents else {
                print("no document for old chats")
                return
            }
            
            var oldMessages = documents.compactMap { (queryDocumentSnapshot) -> LocalMessage? in
                return try? queryDocumentSnapshot.data(as: LocalMessage.self)
            }
            
            oldMessages.sort(by: { $0.date < $1.date })
            
            for message in oldMessages {
                RealmManager.shared.saveToRealm(message)
            }
        }
    }

    func listenForReadStatusChange(_ documentId: String, collectionId: String, completion: @escaping (_ updatedMessage: LocalMessage) -> Void) {
        
        updatedChatListener = FirebaseReference(.Messages).document(documentId).collection(collectionId).addSnapshotListener({ (querySnapshot, error) in
            
            
            guard let snapshot = querySnapshot else { return }
            
            for change in snapshot.documentChanges {
                
                if change.type == .modified {
                    let result = Result {
                        try? change.document.data(as: LocalMessage.self)
                    }
                    
                    switch result {
                    case .success(let messageObject):
                        if let message = messageObject {
                            completion(message)
                        } else {
                            print("Document does not exist chat")
                        }
                    case .failure(let error):
                        print("Error decoding local message: \(error)")
                    }
                }
            }
        })
    }

        
    //MARK: - Add Update Delete
    /// Saves Specific Recent Object to firebase
    ///
    /// - Parameters:
    ///   - recent: The `Recent` Recent Object.
    func addMessage(_ message: LocalMessage, memberId: String) {
      do {
        let _ = try             FirebaseReference(.Messages).document(memberId).collection(message.chatRoomId).document(message.id).setData(from: message)
      }
      catch {
        print(error.localizedDescription, "adding message....")
      }
    }

    func addChannelMessage(_ message: LocalMessage, channel: Channel) {
      do {
        let _ = try FirebaseReference(.Messages).document(channel.id).collection(channel.id ?? "unknownChannel").document(message.id).setData(from: message)
      }
      catch {
        print(error.localizedDescription, "adding message....")
      }
    }

    //MARK: - Update
    func updateMessageInFireStore(_ message: LocalMessage, memberIds: [String]) {

        let values = [kSTATUS : kREAD, kREADDATE : Date()] as [String : Any]

        for userId in memberIds {
            FirebaseReference(.Messages).document(userId).collection(message.chatRoomId).document(message.id).updateData(values)
        }
    }
    
    
    func removeTypingListener() {
        self.newChatListener.remove()
        self.updatedChatListener.remove()
    }
}
