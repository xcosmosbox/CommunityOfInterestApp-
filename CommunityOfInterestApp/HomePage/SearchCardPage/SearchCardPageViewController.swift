//
//  SearchCardPageViewController.swift
//  CommunityOfInterestApp
//
//  Created by Yuxiang Feng on 16/5/2023.
//

import UIKit
import Firebase
import FirebaseFirestoreSwift


class SearchCardPageViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var serachBar: UITextField!
    
    @IBOutlet weak var optionsSegment: UISegmentedControl!
    
    
    @IBOutlet weak var scrollViewComponent: UIScrollView!
    
    @IBOutlet weak var leftStack: UIStackView!
    
    @IBOutlet weak var rightStack: UIStackView!
    
    

    
    
    
    
    
    @IBAction func buttonSearchAction(_ sender: Any) {
        databaseController?.fetchPostsForSearch(serachType: optionsSegment.titleForSegment(at: optionsSegment.selectedSegmentIndex)!, searchText: serachBar.text!, pageSize: self.pageSize, currentDocument: currentDocument){ (searchResult, newCurrentDocument) in
            
            var counter = 0
            if self.left_card_list.count > self.right_card_list.count{
                counter = 1
            } else{
                counter = 0
            }
            
            for card in searchResult{
                if counter == 0{
                    let aCardView = CardFactory().buildACardView(username: card.username!, title: card.title!, imagePath: card.cover!, homepageViewControl: self, card: card)
                    self.left_card_list.append(aCardView)
                    self.leftStack.addArrangedSubview(aCardView)
                    counter = 1
                } else{
                    let aCardView = CardFactory().buildACardView(username: card.username!, title: card.title!, imagePath: card.cover!, homepageViewControl: self, card: card)
                    self.right_card_list.append(aCardView)
                    self.rightStack.addArrangedSubview(aCardView)
                    counter = 0
                    
                }
            }
            
            self.currentDocument = newCurrentDocument
            
            self.refresh()
            
        }
    }
    
    
    
    var posts: [Card] = []
    var currentDocument: DocumentSnapshot?
    
    let pageSize:Int = 10
    
    var searchType: String = "Tag"
    var serachText: String = ""
    
    var left_card_list:[CardView] = []
    var right_card_list:[CardView] = []
    
    // connection for database
    weak var databaseController: DatabaseProtocol?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // obtain the connection for database controller
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        databaseController = appDelegate?.databaseController
        
        // Do any additional setup after loading the view.
        
        
        scrollViewComponent.delegate = self
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func refresh(){
        var max_height = 0
        
        leftStack.frame.size.height = CGFloat(left_card_list.count * 250 + 30 * left_card_list.count)
        rightStack.frame.size.height = CGFloat(right_card_list.count * 250 + 30 * right_card_list.count)
        
        if leftStack.frame.height > rightStack.frame.height{
            max_height = Int(leftStack.frame.height)
        }else{
            max_height = Int(rightStack.frame.height)
        }
        
        scrollViewComponent.contentSize = CGSize(width: scrollViewComponent.frame.width, height: CGFloat(max_height))
        
        scrollViewComponent.alwaysBounceVertical = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.height
        
        if offsetY > contentHeight - height {
            databaseController?.fetchPostsForSearch(serachType: optionsSegment.titleForSegment(at: optionsSegment.selectedSegmentIndex)!, searchText: serachBar.text!, pageSize: self.pageSize, currentDocument: currentDocument){ (searchResult, newCurrentDocument) in
                
                var counter = 0
                if self.left_card_list.count > self.right_card_list.count{
                    counter = 1
                } else{
                    counter = 0
                }
                
                for card in searchResult{
                    if counter == 0{
                        let aCardView = CardFactory().buildACardView(username: card.username!, title: card.title!, imagePath: card.cover!, homepageViewControl: self, card: card)
                        self.left_card_list.append(aCardView)
                        self.leftStack.addArrangedSubview(aCardView)
                        counter = 1
                    } else{
                        let aCardView = CardFactory().buildACardView(username: card.username!, title: card.title!, imagePath: card.cover!, homepageViewControl: self, card: card)
                        self.right_card_list.append(aCardView)
                        self.rightStack.addArrangedSubview(aCardView)
                        counter = 0
                    }
                }
                
                self.currentDocument = newCurrentDocument
                
                self.refresh()
                
            }
        }
    }
    

    
    

}
