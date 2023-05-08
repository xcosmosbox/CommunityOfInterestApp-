//
//  FirebaseController.swift
//  CommunityOfInterestApp
//
//  Created by Yuxiang Feng on 25/4/2023.
//
import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift
import FirebaseStorage

class FirebaseController: NSObject, DatabaseProtocol {
 
    

    


    

    

    
   
    
    var defaultTags: [Tag] = []
    var currentCards: [Card] = []
    var listeners = MulticastDelegate<DatabaseListener>()
    
    // reference to firebase
    var authController: Auth
    var database: Firestore
    var fireStorage: Storage
    var deafultTagRef: CollectionReference?
    var postRef: CollectionReference?
    var userRef: CollectionReference?
    var currentUser: FirebaseAuth.User?
    
    // card cache pool
    var oneCardCache: Card? = nil
    
    // user login state
    var userLoginState: Bool
    var currentUserLikesList: [Card] = []
    var currentUserCollectionsList: [Card] = []
    var currentUserPostsList: [Card] = []
    
    // edit and push post
    var currentImages: [UIImage] = []
    var currentImagesCounter: Int = 0
    
    
    override init() {
        FirebaseApp.configure()
        authController = Auth.auth()
        database = Firestore.firestore()
        fireStorage = Storage.storage()
        userLoginState = false
        
        super.init()
        
        // anonymous sign in
//        Task{
//            do {
//                let authDataResult = try await authController.signInAnonymously()
//                currentUser = authDataResult.user
//
//                // create corresponding user document
//                try await database.collection("user").document(currentUser!.uid).setData([
//                    "name": "username",
//
//                ])
//            }
//            catch {
//                // sign in failed
//                fatalError("Firebase Authentication Failed with Error \(String(describing: error))")
//            }
//
//            // sign in success
//            self.setupDefaultTags()
//
//            // init user's tags list
////            do{
////                print("=====hahahahahahaha====")
////                try await database.collection("user").document(currentUser!.uid).updateData([
////                    "tags": FieldValue.arrayUnion(defaultTags)
////                ])
////                print("=====hahahahahahaha====")
////            }
//
//        }
    }

    
    
    func cleanup() {
        // nothing to do
    }
    
    func addListener(listener: DatabaseListener) {
        listeners.addDelegate(listener)
        
        if listener.listenerType == .tag || listener.listenerType == .all || listener.listenerType == .tagAndExp{
            print("appear HOME")
            print(defaultTags)
            listener.onTagChange(change: .update, tags: self.defaultTags)
        }
        
        if listener.listenerType == .explore || listener.listenerType == .all || listener.listenerType == .tagAndExp{
            listener.onExploreChange(change: .update, cards: self.currentCards)
        }
        
        if listener.listenerType == .auth || listener.listenerType == .all{
            listener.onAuthChange(change: .update, userIsLoggedIn: userLoginState, error: "")
        }
        
        if listener.listenerType == .person || listener.listenerType == .all{
            listener.onPersonChange(change: .update, postsCards: self.currentUserPostsList, likesCards: self.currentUserLikesList, collectionsCards: self.currentUserCollectionsList)
        }
        
    }
    
    func removeListener(listener: DatabaseListener) {
        listeners.removeDelegate(listener)
    }
    
    
    
    func addTag(name: String) -> Tag {
        let tag = Tag()
        tag.name = name
        
        // add one tag for firestore
        // only for dev level, will be modified in the future
        database.collection("user").document(currentUser!.uid).updateData([
            "tags": FieldValue.arrayUnion([tag.name!])
        ]) {
            error in
            
            if let error = error {
                print("add new tag error: \(error)")
            } else {
                print("add new tag successfully")
            }
        }
        
        // add one tag on local
        self.defaultTags.append(tag)
        
        return tag
        
    }
    
    
    func deleteTag(tag: Tag) {
        // delete one tag for firestore
        database.collection("user").document(currentUser!.uid).updateData([
            "tags": FieldValue.arrayRemove([tag.name])
        ]){ error in
            if let error = error{
                print("delete a tag error: \(error)")
            } else {
                print("delete a tag successfully")
            }
        }
        
        // delete one tag on local
        self.defaultTags.removeAll(where: {$0.name == tag.name})
        
    }
    
    
    
    func addCard(card: Card) -> Card {
        // milestone 2
        let card = Card()
        return card
    }
    
    func deleteCard(card: Card) {
        // milestone 2
    }
    
    func getCommunityContentByTag(tagNmae: String) {
        
        // remove all cards
        currentCards = []
        
        if tagNmae == " Explore "{
            postRef?.limit(to: 15).getDocuments{ (querySnapshot, error) in
                
                guard let querySnapshot = querySnapshot else{
                    print("Failed to get documents with error on getCommunityContentByTag: \(String(describing: error))")
                    return
                }
                
                self.parseCardsSnapshotFromNewTag(snapshot: querySnapshot)
                
            }
            
        } else {
            let name = tagNmae.trimmingCharacters(in: .whitespacesAndNewlines)
            // get new cards
            postRef?.whereField("tags", arrayContains: name).limit(to: 10).getDocuments{ (querySnapshot, error) in
                if let error = error{
                    print("error::::\(error)")
                } else {
                    
                    guard let querySnapshot = querySnapshot else{
                        print("Failed to get documents by tag name with error: \(String(describing: error))")
                        return
                    }
                    self.parseCardsSnapshotFromNewTag(snapshot: querySnapshot)
                }
            }
        }
        
    }
    
    
    
//    func setupDefaultTags(){
//
//        deafultTagRef = database.collection("default_tag")
//        deafultTagRef?.addSnapshotListener(){
//            (querySnapshot, error) in
//
//            guard let querySnapshot = querySnapshot else{
//                print("Failed to fetch documents with error: \(String(describing: error))")
//                return
//            }
//
//            self.parseTagsSnapshot(snapshot: querySnapshot)
//
//            if self.postRef == nil{
//                self.setupCurrentCards()
//            }
//
//
//        }
//
//    }
    
    
    func setupCurrentCards() {
        
        postRef = database.collection("post")
        postRef?.limit(to: 15).getDocuments{ (querySnapshot, error) in
            
            guard let querySnapshot = querySnapshot else{
                print("Failed to get documents with error: \(String(describing: error))")
                return
            }
            
            self.parseCardsSnapshot(snapshot: querySnapshot)
            
        }
        
        
        
        
    }
    
    
    func parseTagsSnapshot(snapshot: QuerySnapshot){
        snapshot.documentChanges.forEach{ (change) in
            
            var parsedTag: Tag?
            
            do {
                parsedTag = try change.document.data(as: Tag.self)
                print(parsedTag?.name)
            } catch {
                print("Unable to decode tag. Is the tag malformed?")
                return
            }
            
            guard let tag = parsedTag else{
                print("Document doesn't exist")
                return
            }
            
            if change.type == .added{
                print(defaultTags)
                defaultTags.insert(tag, at: Int(change.newIndex))
            } else if change.type == .modified{
                defaultTags[Int(change.oldIndex)] = tag
            } else if change.type == .removed {
                defaultTags.remove(at: Int(change.oldIndex))
            }
            
            database.collection("user").document(currentUser!.uid).updateData([
                "tags": FieldValue.arrayUnion([tag.name!])
            ])
            
            listeners.invoke{ (listener) in
                if listener.listenerType == ListenerType.tag || listener.listenerType == ListenerType.all || listener.listenerType == .tagAndExp{
                    listener.onTagChange(change: .update, tags: self.defaultTags)
                }
                
            }
            
            
            
        }
    }
    
    
    func parseCardsSnapshot(snapshot: QuerySnapshot){
        
        snapshot.documentChanges.forEach{ (change) in
            
            var parsedCard: Card?
            
            do{
                parsedCard = try change.document.data(as: Card.self)
                print(parsedCard?.cover)
            } catch {
                print("Unable to decode card. Is the card malformed?")
                return
            }
            
            guard let card = parsedCard else{
                print("Document doesn't exits")
                return
            }
            
            if change.type == .added{
                print(currentCards)
                currentCards.insert(card, at: Int(change.newIndex))
            } else if change.type == .modified{
                currentCards[Int(change.oldIndex)] = card
            } else if change.type == .removed {
                currentCards.remove(at: Int(change.oldIndex))
            }
            
//            listeners.invoke{ (listener) in
//                if listener.listenerType == ListenerType.explore || listener.listenerType == ListenerType.all || listener.listenerType == .tagAndExp{
//                    listener.onExploreChange(change: .update, cards: self.currentCards)
//                }
//
//            }
            
            
        }
        
        listeners.invoke{ (listener) in
            if listener.listenerType == ListenerType.explore || listener.listenerType == ListenerType.all || listener.listenerType == .tagAndExp{
                listener.onExploreChange(change: .update, cards: self.currentCards)
            }
            
        }
        
    }
    
    
    func parseCardsSnapshotFromNewTag(snapshot: QuerySnapshot){
        print("hduaishdi!!!!!!!!!1duaishdi!!!!!!")
        print(snapshot.documentChanges.count)
        snapshot.documentChanges.forEach{ (change) in
            
            var parsedCard: Card?
            
            do{
                parsedCard = try change.document.data(as: Card.self)
                print(parsedCard?.cover)
            } catch {
                print("Unable to decode card. Is the card malformed?")
                return
            }
            
            guard let card = parsedCard else{
                print("Document doesn't exits")
                return
            }
            
            if change.type == .added{
                print(currentCards)
                currentCards.insert(card, at: Int(change.newIndex))
            } else if change.type == .modified{
                currentCards[Int(change.oldIndex)] = card
            } else if change.type == .removed {
                currentCards.remove(at: Int(change.oldIndex))
            }
        }
            
            
        listeners.invoke{ (listener) in
            if listener.listenerType == ListenerType.explore || listener.listenerType == ListenerType.all || listener.listenerType == .tagAndExp{
                listener.onExploreChange(change: .reload, cards: self.currentCards)
            }
                
        }
        
        
    }
    
    
    
//    func downloadImage(path: String) -> Data {
//        let gsReference = Storage.storage().reference(forURL: path)
//
//        gsReference.getData(maxSize: 10 * 1024 * 1024){ data, error in
//
//            print(type(of: data))
//            if let error = error{
//                print("error!: \(error)")
//            } else {
////                image = UIImage(data: data!)
//            }
//
//        }
//
////        return image
//
//    }
    
    
    func setOneCardCache(card: Card) {
        self.oneCardCache = card
    }
    
    func getOneCardCache() -> Card {
        return self.oneCardCache!
    }

    
    
    func login(email: String, password: String) {
        Task{
            do{
                // using authController.signIn function to login firebase auth
                let authDataResult = try await authController.signIn(withEmail: email, password: password)
                // get user data
                currentUser = authDataResult.user
                userLoginState = true
                
                let userDocRef = database.collection("user").document(currentUser!.uid)
                userDocRef.getDocument{ (document, error) in
                    if let document = document, document.exists{
                        let data = document.data()
                        let userTags = data?["tags"] as? [String] ?? []
                        userTags.forEach{ tag in
                            let oneTag = Tag()
                            oneTag.name = tag
                            self.defaultTags.append(oneTag)
                        }
                        
                        self.listeners.invoke{ (listener) in
                            if listener.listenerType == ListenerType.tag || listener.listenerType == ListenerType.all || listener.listenerType == .tagAndExp{
                                listener.onTagChange(change: .update, tags: self.defaultTags)
                            }
                            
                        }
                        
                        if self.postRef == nil{
                            self.setupCurrentCards()
                        }
                        
                        self.listeners.invoke{ (listener) in
                            if listener.listenerType == ListenerType.auth || listener.listenerType == ListenerType.all{
                                listener.onAuthChange(change: .update, userIsLoggedIn: self.userLoginState, error: "")
                            }
                            
                        }
                        
                        self.parseUserCardViewList()
                        
                    } else{
                        print("Document does not exist: setupUserSelectedTags")
                    }
                    
                }

                
                
                
                
            } catch{
                // login failed
                print("Firebase Authentication Failed with Error \(String(describing: error))")
            }
        }
        
        
        
        
    }
    
    func signup(newEmail: String, newPassword: String) {
        Task{
            do{
                // using createUser function to signup account
                let authDataResult = try await authController.createUser(withEmail: newEmail, password: newPassword)
                
                // get user data
                currentUser = authDataResult.user
                
                // using user id to create the user document
                // we need to set the document ID == user id
                print("doahduoahsduoad")
                print("\(currentUser?.uid)")
//                try await database.collection("user").document(currentUser!.uid).setData([
//                    "name": "username",
//                    "profile":"everything you love is here",
//                    "profile_image":"gs://fit3178-final-ci-app.appspot.com/WechatIMG88.jpeg"
//                ])
//                let name = "usernmae"
//                try await database.collection("user").document(currentUser!.uid).setData([
//                    "name": name,
//                ])
                
                // init
                
                // set user login state
                userLoginState = true
                
                
            } catch {
                print("set user tags failed with error: \(error)")
            }
        }
    }
    
    func setupUserSelectedTags(tags: [String]) -> Bool {
        do{
            database.collection("user").document(currentUser!.uid).setData([
                "name": "username",
                "profile":"everything you love is here",
                "profile_image":"gs://fit3178-final-ci-app.appspot.com/WechatIMG88.jpeg",
                "collections":[],
                "follower":[],
                "following":[],
                "likes":[],
                "posts":[],
                "tags":tags
            ])
            
            userLoginState = true
            
            print("set user tag success")
            
            let userDocRef = database.collection("user").document(currentUser!.uid).addSnapshotListener{
                (querySnapshot, error) in
                print("dhoashdoasuhduaoshdouashdouashd")
                
                guard let querySnapshot = querySnapshot else {
                    print("Failed to get documet for this user --> \(error!)")
                    return
                }
                
                if querySnapshot.data() == nil{
                    print("Failed to get documet for this user")
                    return
                }
                
                if let userTagsFromDatabase = querySnapshot.data()!["tags"] as? [String]{
                    print("hihiiiiiiaisdiasidasidais")
                    for userOneTag in userTagsFromDatabase{
                        let oneTag = Tag()
                        oneTag.name = userOneTag
                        self.defaultTags.append(oneTag)
                        print(userOneTag)
                        print(oneTag)
                    }
                    
                    print("=========================================================================")
                    print(self.defaultTags)
                    print("=========================================================================")
                    self.listeners.invoke{ (listener) in
                        if listener.listenerType == ListenerType.tag || listener.listenerType == ListenerType.all || listener.listenerType == .tagAndExp{
                            print("test for tag change on signup")
                            listener.onTagChange(change: .update, tags: self.defaultTags)
                        }
                        
                    }
                    
                    
                    if self.postRef == nil{
                        self.setupCurrentCards()
                    }
                    
                    
                }else{
                    print("Document does not exist: setupUserSelectedTags")
                }
                
                
                
            }

            
            
            return true
            
        } catch {
            print("set user tags failed with error: \(error)")
            return false
        }
    }
    
    
//    func getUserModel() -> User {
//        var userModel = User()
//        let userDocRef = database.collection("user").document(currentUser!.uid).addSnapshotListener{
//            (querySnapshot, error) in
//
//            guard let querySnapshot = querySnapshot else {
//                print("Failed to get documet for this user --> \(error!)")
//                return
//            }
//
//            if querySnapshot.data() == nil{
//                print("Failed to get documet for this user")
//                return
//            }
//
//
//            if let name = querySnapshot.data()!["name"] as? String {
//                userModel.name = name
//            }
//
//            if let profile = querySnapshot.data()!["profile"] as? String {
//                userModel.profile = profile
//            }
//
//            print("()()()()())(()()()()())(()()()()())(()()()()())(()()()()())(")
//            if let profile_image = querySnapshot.data()!["profile_image"] as? String {
//                userModel.profile_image = profile_image
//                print(profile_image)
//                print("()()()()())(()()()()())(()()()()())(()()()()())(()()()()())(")
//            }
//
//            if let tags = querySnapshot.data()!["tags"] as? [String] {
//                userModel.tags = tags
//            }
//
//            if let collections = querySnapshot.data()!["collections"] as? [DocumentReference] {
//                userModel.collections = collections
//            }
//
//            if let follower = querySnapshot.data()!["follower"] as? [DocumentReference] {
//                userModel.follower = follower
//            }
//
//            if let following = querySnapshot.data()!["following"] as? [DocumentReference] {
//                userModel.following = following
//            }
//
//            if let likes = querySnapshot.data()!["likes"] as? [DocumentReference] {
//                userModel.likes = likes
//            }
//
//            if let posts = querySnapshot.data()!["posts"] as? [DocumentReference] {
//                userModel.posts = posts
//            }
//
//
//
//        }
//
//        return userModel
//
//
//
//
//    }
    
    
    func getUserModel(completion: @escaping (User) -> Void) {
        var userModel = User()
        let userDocRef = database.collection("user").document(currentUser!.uid).addSnapshotListener {
            (querySnapshot, error) in
            
            guard let querySnapshot = querySnapshot else {
                print("Failed to get documet for this user --> \(error!)")
                return
            }
            
            if querySnapshot.data() == nil{
                print("Failed to get documet for this user")
                return
            }
            
            if let id = querySnapshot.documentID as? String{
                userModel.id = id
            }
            
            if let name = querySnapshot.data()!["name"] as? String {
                userModel.name = name
            }
            
            if let profile = querySnapshot.data()!["profile"] as? String {
                userModel.profile = profile
            }
            
            if let profile_image = querySnapshot.data()!["profile_image"] as? String {
                userModel.profile_image = profile_image
            }
        
            if let tags = querySnapshot.data()!["tags"] as? [String] {
                userModel.tags = tags
            }
        
            if let collections = querySnapshot.data()!["collections"] as? [DocumentReference] {
                userModel.collections = collections
            }
            
            if let follower = querySnapshot.data()!["follower"] as? [DocumentReference] {
                userModel.follower = follower
            }
            
            if let following = querySnapshot.data()!["following"] as? [DocumentReference] {
                userModel.following = following
            }
            
            if let likes = querySnapshot.data()!["likes"] as? [DocumentReference] {
                userModel.likes = likes
            }
            
            if let posts = querySnapshot.data()!["posts"] as? [DocumentReference] {
                userModel.posts = posts
            }
            
            completion(userModel)
        }
    }

    
    
    func parseUserCardViewList(){
        Task{
            do{
                getUserModel{ userModel in
                    self.parsePostsList(referencesList: userModel.posts!)
                    self.parseLikesList(referencesList: userModel.likes!)
                    self.parseCollectionsList(referencesList: userModel.collections!)
                }
            }
        }
        
        
//
//        var cardsList:[Card]?
//
//        referencesList.forEach{ eachReference in
//            eachReference.addSnapshotListener{ (querySnapshot, error) in
//                // check
//                guard let querySnapshot = querySnapshot else {
//                    print("Failed to get documet for this user --> \(error!)")
//                    return
//                }
//
//                // check
//                if querySnapshot.data() == nil{
//                    print("Failed to get documet for this user")
//                    return
//                }
//
//                // add card into list
//                do{
//                    let card = try querySnapshot.data(as: Card.self)
//                    cardsList?.append(card)
//                } catch {
//                    print("Unable to decod card: parseUserCardViewList")
//                    return
//                }
//
//
//
//            }
//
//        }
//
//        return cardsList!
    }
    
    func parsePostsList(referencesList: [DocumentReference]){
        do{
            referencesList.forEach{ referenceDoc in
                referenceDoc.getDocument{ (document, error) in
                    if let error = error{
                        print("error parsePostsList:\(error)")
                    } else if let document = document{
                        do{
                            let card = try document.data(as: Card.self)
                            if card == nil{
                                print("Failed to parse card")
                            }else{
//                                print("=================(((((((^^^^^^^^^^^")
//                                print(card)
//                                print("=================(((((((^^^^^^^^^^^")
                                self.currentUserPostsList.append(card)
                            }
                            
                            self.listeners.invoke{ (listener) in
                                if listener.listenerType == ListenerType.person || listener.listenerType == ListenerType.all{
                                    listener.onPersonChange(change: .update, postsCards: self.currentUserPostsList, likesCards: self.currentUserLikesList, collectionsCards: self.currentUserCollectionsList)
                                }
                                
                            }
                            
                        }catch{
                            print("error parsePostsList catch:\(error)")
                        }
                    }
                    
                }
                
            }
        }
    }
    func parseLikesList(referencesList: [DocumentReference]){
        do{
            referencesList.forEach{ referenceDoc in
                referenceDoc.getDocument{ (document, error) in
                    if let error = error{
                        print("error parsePostsList:\(error)")
                    } else if let document = document{
                        do{
                            let card = try document.data(as: Card.self)
                            if card == nil{
                                print("Failed to parse card")
                            }else{
//                                print("=================(((((((^^^^^^^^^^^")
//                                print(card)
//                                print("=================(((((((^^^^^^^^^^^")
                                self.currentUserLikesList.append(card)
                            }
                            
                            self.listeners.invoke{ (listener) in
                                if listener.listenerType == ListenerType.person || listener.listenerType == ListenerType.all{
                                    listener.onPersonChange(change: .update, postsCards: self.currentUserPostsList, likesCards: self.currentUserLikesList, collectionsCards: self.currentUserCollectionsList)
                                }
                                
                            }
                            
                        }catch{
                            print("error parsePostsList catch:\(error)")
                        }
                    }
                    
                }
                
            }
        }
    }
    func parseCollectionsList(referencesList: [DocumentReference]){
        do{
            referencesList.forEach{ referenceDoc in
                referenceDoc.getDocument{ (document, error) in
                    if let error = error{
                        print("error parsePostsList:\(error)")
                    } else if let document = document{
                        do{
                            let card = try document.data(as: Card.self)
                            if card == nil{
                                print("Failed to parse card")
                            }else{
                                self.currentUserCollectionsList.append(card)
                            }
                            
                            self.listeners.invoke{ (listener) in
                                if listener.listenerType == ListenerType.person || listener.listenerType == ListenerType.all{
                                    listener.onPersonChange(change: .update, postsCards: self.currentUserPostsList, likesCards: self.currentUserLikesList, collectionsCards: self.currentUserCollectionsList)
                                }
                                
                            }
                            
                        }catch{
                            print("error parsePostsList catch:\(error)")
                        }
                    }
                    
                }
                
            }
        }
    }
    
    
    
    // edit and push post
    func saveCurrentImagesAsDraft(images: [UIImage]) {
        for image in images{
            self.currentImages.append(image)
        }
    }
    
    func clearCurrentImages() {
        self.currentImages.removeAll()
    }
    
    func uploadCurrentImagesForCard(title: String, content: String, selectedTags: [String], completion: @escaping (DocumentReference) -> Void) {
        self.currentImagesCounter = 0
        
        Task{
            let folderPath = "images/\(self.currentUser?.uid ?? "hFeuyISsXUWxdOUV5LynsgIH4lC2")/"
            do{
                self.createPostCardForFirebase(title: title, content: content, selectedTags: selectedTags){ createdPostCardRef in
                    for image in self.currentImages{
                        DispatchQueue.main.async {
                            self.uploadImageToStorage(folderPath: folderPath, image: image){ storageLocationStr in
                                DispatchQueue.main.async {
                                    if self.currentImagesCounter == 0{
                                        createdPostCardRef.updateData([
                                            "cover":"gs://fit3178-final-ci-app.appspot.com/\(storageLocationStr)"
                                        ])
                                        self.currentImagesCounter += 1
                                    }
                                    createdPostCardRef.updateData([
                                        "picture": FieldValue.arrayUnion(["gs://fit3178-final-ci-app.appspot.com/\(storageLocationStr)"])
                                    ])
                                    self.currentImagesCounter += 1
                                    
                                    if self.currentImagesCounter == self.currentImages.count{
                                        completion(createdPostCardRef)
                                    }
                                }
                            }
                        }
                    }
                    
                    
                }
            }
        }
        
        
    }
    
    func createPostCardForFirebase(title: String, content: String, selectedTags: [String], completion: @escaping (DocumentReference) -> Void){
        
        Task{
            do{
                self.getUserModel{ userModel in
                    DispatchQueue.main.async {
                        let documentRef = self.database.collection("post").document()
                        documentRef.setData([
                            "audio":[],
                            "content":content,
                            "cover":"",
                            "likes_number":0,
                            "picture":[],
                            "publisher":self.database.collection("user").document(userModel.id!),
                            "tags":selectedTags,
                            "title":title,
                            "username":userModel.name!,
                            "video":[]
                        ])
                        completion(documentRef)
                        
                    }
                }
                
               
            }catch{
                print("can not get the usermodel in firebase\(error)")
            }
        }
        
    }
    
    func uploadImageToStorage(folderPath: String, image:UIImage, completion: @escaping (String) -> Void){
        Task{
            // build the storage reference
            let path = folderPath + "imageName_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpeg"
            let storageRef = self.fireStorage.reference(withPath: path)
            
            // build the imageData
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                // image transfer to data faild
                return
            }
            
            // upload image
            do{
                // create a uploadTask by using await key word and putData function
                let uploadTask = try await storageRef.putData(imageData)
                
                try await uploadTask.observe(.progress){ storageTaskSnapshot in
                    
                    let progress = storageTaskSnapshot.progress
                    
                    let percentComplete = 100.0 * Double(progress!.completedUnitCount) / Double(progress!.totalUnitCount)
                    
                    
//                    print("progress: \(percentComplete)")
                    
                    if percentComplete == 100.0{
                        // check and get storage location
                        if storageTaskSnapshot.reference.fullPath != nil{
                            completion(storageTaskSnapshot.reference.fullPath)
                        }
                        
                    }
                    
                    
                }
                
                
            } catch{
                print("error for upload task: error")
            }
            
        }
    }
        
        
   
       
        
    
    
    
    
    
    
}
