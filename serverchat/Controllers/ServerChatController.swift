//
//  ServerChatController.swift
//  serverchat
//
//  Created by David Oliver Doswell on 1/25/18.
//  Copyright © 2018 David Oliver Doswell. All rights reserved.
//

import UIKit
import Firebase
import FirebaseStorage

private let reuseIdentifier = "reuseIdentifier"
private let sendButtonTitle = "Send"
private let inputTextFieldPlaceholder = "New message"

class ServerChatController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var user: User? {
        didSet {
            self.navigationItem.title = user?.name
            observeMessages()
        }
    }
    
    // Input textfield class reference
    lazy var inputTextField : UITextField = {
        let textField = UITextField()
        textField.clearsOnBeginEditing = true
        textField.attributedPlaceholder = NSAttributedString(string: inputTextFieldPlaceholder, attributes: [NSAttributedStringKey.foregroundColor : UIColor.white])
        textField.textColor = .white
        textField.tintColor = .white
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black

        // Customize nav bar items
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTap(sender:)))
        
        self.collectionView?.alwaysBounceVertical = true
        self.collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 58, right: 0)
        self.collectionView?.keyboardDismissMode = .interactive
        self.collectionView?.register(ServerChatCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        setUpKeyboardObservers()
    }
    
    @objc func backTap(sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    var messages = [Message]()
    
    func observeMessages() {
        guard let uid = Auth.auth().currentUser?.uid, let toUserID = user?.id else { return }
        
        let userMessageReference = Database.database().reference().child("user-messages").child(uid).child(toUserID)
        userMessageReference.observe(.childAdded, with: { (snapshot) in
            
            let messageID = snapshot.key
            let messagesRef = Database.database().reference().child("messages").child(messageID)
            messagesRef.observe(.value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String:AnyObject] else { return }
                self.messages.append(Message(dictionary: dictionary))
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                    
                    let indexPath = IndexPath(item: self.messages.count - 1, section: 0)
                    self.collectionView?.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.bottom, animated: true)
                }
            }, withCancel: nil)
        }, withCancel: nil)
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { view.endEditing(true) }
    
    // Data source
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        if let text = message.text {
            height = estimatedFrameForText(text: text).height + 20
        } else if let imageWidth = message.imageWidth?.floatValue, let imageHeight = message.imageHeight?.floatValue {
            
            height = CGFloat(imageHeight / imageWidth * 200)
        }
        return CGSize(width: view.frame.width, height: height)
    }
    
    private func estimatedFrameForText(text: String) -> CGRect {
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ServerChatCell
        
        cell.serverChatController = self
        
        let message = messages[indexPath.item]
        setUpCell(cell: cell, message: message)
        cell.chatTextView.text = message.text
        
        if let text = message.text {
            cell.bubbleWidthAnchor?.constant = estimatedFrameForText(text: text).width + 32
            cell.chatTextView.isHidden = false
        } else if message.imageURL != nil {
            cell.bubbleWidthAnchor?.constant = 200
            cell.chatTextView.isHidden = true
        }

        return cell
    }
    
    private func setUpCell(cell: ServerChatCell, message: Message) {
        if let serverImageURL = self.user?.serverImageURL {
            cell.serverImageView.cacheImage(urlString: serverImageURL)
        }
        
        if message.fromUserID == Auth.auth().currentUser?.uid {
            cell.bubbleView.backgroundColor = .white
            cell.chatTextView.textColor = .black
            cell.serverImageView.isHidden = true
            
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        } else {
            cell.bubbleView.backgroundColor = .black
            cell.chatTextView.textColor = .white
            cell.bubbleView.layer.borderWidth = 1
            cell.bubbleView.layer.borderColor = UIColor.white.cgColor
            cell.serverImageView.isHidden = false

            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
        
        if let messageImageURL = message.imageURL {
            cell.messageImageView.cacheImage(urlString: messageImageURL)
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = .clear
        } else {
            cell.messageImageView.isHidden = true
        }
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
    lazy var inputContainerView: UIView = {
        
        // Container view
        let containerView = UIView()
        containerView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 50)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black
        
        // Image view
        let uploadImageButton = UIButton()
        uploadImageButton.setImage(UIImage(named: "Upload"), for: .normal)
        uploadImageButton.layer.cornerRadius = 22
        uploadImageButton.layer.masksToBounds = true
        uploadImageButton.isUserInteractionEnabled = true
        uploadImageButton.addTarget(self, action: #selector(handleUpLoad), for: .touchUpInside)
        uploadImageButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(uploadImageButton)
        
        uploadImageButton.leftAnchor.constraint(equalTo: containerView.leftAnchor).isActive = true
        uploadImageButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        uploadImageButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        uploadImageButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // Send button
        let sendButton = UIButton(type: .system)
        sendButton.setTitle(sendButtonTitle, for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.addTarget(self, action: #selector(sendButtonTap), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sendButton)
        
        sendButton.rightAnchor.constraint(equalTo: containerView.rightAnchor).isActive = true
        sendButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        sendButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        sendButton.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        
        // Input textfield constraints
        containerView.addSubview(inputTextField)
        inputTextField.leftAnchor.constraint(equalTo: uploadImageButton.rightAnchor, constant: 8).isActive = true
        inputTextField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        inputTextField.rightAnchor.constraint(equalTo: sendButton.leftAnchor).isActive = true
        inputTextField.heightAnchor.constraint(equalTo: containerView.heightAnchor).isActive = true
        
        // Separator
        let separatorLineView = UIView()
        separatorLineView.backgroundColor = .white
        separatorLineView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(separatorLineView)
        
        separatorLineView.leftAnchor.constraint(equalTo:  containerView.leftAnchor).isActive = true
        separatorLineView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        separatorLineView.widthAnchor.constraint(equalTo: containerView.widthAnchor).isActive = true
        separatorLineView.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        
        return containerView
    }()
    
    override var inputAccessoryView: UIView? {
        get {
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder : Bool {
        return true
    }
    
    @objc func handleUpLoad() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        var selectedPickerImage: UIImage?
        
        if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            selectedPickerImage = editedImage
        } else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            selectedPickerImage = originalImage
        }
        if let selectedImage = selectedPickerImage {
            DispatchQueue.main.async {
                self.uploadToStorage(image: selectedImage)
            }
        }
        dismiss(animated: true, completion: nil)
    }
    
    private func uploadToStorage(image: UIImage) {
        let imageName = NSUUID().uuidString
        let ref = Storage.storage().reference().child("message_inages").child(imageName)
        
        if let uploadData = UIImageJPEGRepresentation(image, 0.2) {
            ref.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription as Any)
                }
                if let imageURL = metadata?.downloadURL()?.absoluteString {
                    self.sendMessageWithURL(imageURL: imageURL, image: image)
                }
            })
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func setUpKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }
    
    @objc func keyboardDidShow() {
        if messages.count > 0 {
            let indexPath = IndexPath(item: messages.count - 1, section: 0)
            collectionView?.scrollToItem(at: indexPath, at: .top, animated: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let keyboardFrame = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as! CGRect
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = -keyboardFrame.height
        UIView.animate(withDuration: keyboardDuration!) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = 0
        UIView.animate(withDuration: keyboardDuration!) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func sendButtonTap() {
        let properties = ["text" : inputTextField.text!]
        sendMessagesWithProperties(properties: properties as [String : AnyObject])
    }
    
    private func sendMessageWithURL(imageURL: String, image: UIImage) {
        let properties: [String:AnyObject] = ["imageURL" : imageURL as AnyObject, "imageWidth": image.size.width as AnyObject, "imageHeight": image.size.height as AnyObject]
        sendMessagesWithProperties(properties: properties)
    }
    
    private func sendMessagesWithProperties(properties: [String:AnyObject]) {
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        
        let toUserID = user!.id!
        let fromUserID = Auth.auth().currentUser!.uid
        let timestamp = Int(Date().timeIntervalSince1970)
        var values = ["toUserID" : toUserID, "fromUserID" : fromUserID, "timestamp" : timestamp] as [String : Any]
        
        properties.forEach({values[$0] = $1})
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                print(error!.localizedDescription)
            }
            self.inputTextField.text = nil
            let userMessageRef = Database.database().reference().child("user-messages").child(fromUserID).child(toUserID)
            
            let messageID = childRef.key
            userMessageRef.updateChildValues([messageID: 1])
            
            let recipientUserMessagesRef = Database.database().reference().child("user-messages").child(toUserID).child(fromUserID)
            recipientUserMessagesRef.updateChildValues([messageID: 1])
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendButtonTap()
        return true
    }
    
    var startingFrame: CGRect?
    var blackBackground: UIView?
    var startingImageView: UIImageView?
    
    func performZoomInForStartingImageView(startingImageView: UIImageView) {
        self.startingImageView = startingImageView
        self.startingImageView?.isHidden = true
        
        startingFrame = startingImageView.superview?.convert(startingImageView.frame, to: nil)
        
        let zoomingImageView = UIImageView(frame: self.startingFrame!)
        zoomingImageView.image = startingImageView.image
        zoomingImageView.isUserInteractionEnabled = true
        zoomingImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(zoomOut)))
        
        if let keyWindow = UIApplication.shared.keyWindow {
            blackBackground = UIView(frame: keyWindow.frame)
            blackBackground?.backgroundColor = .black
            self.blackBackground?.alpha = 0
            keyWindow.addSubview(blackBackground!)
            
            keyWindow.addSubview(zoomingImageView)
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.blackBackground?.alpha = 1
                self.inputContainerView.alpha = 0
                
                let height = self.startingFrame!.height / self.startingFrame!.width * keyWindow.frame.width
                
                zoomingImageView.frame = CGRect(x: 0, y: 0, width: keyWindow.frame.width, height: height)
                zoomingImageView.center = keyWindow.center
            }, completion: { (completedl) in
            })
        }
    }
    
    @objc func zoomOut(tapGesture: UITapGestureRecognizer) {
        if let zoomOutImageView = tapGesture.view {
            zoomOutImageView.layer.cornerRadius = 16
            zoomOutImageView.layer.masksToBounds = true
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                zoomOutImageView.frame = self.startingFrame!
                self.blackBackground?.alpha = 0
                self.inputContainerView.alpha = 1
            }, completion: { (completedl) in
                zoomOutImageView.removeFromSuperview()
                self.startingImageView?.isHidden = false
            })
        }
    }
}








