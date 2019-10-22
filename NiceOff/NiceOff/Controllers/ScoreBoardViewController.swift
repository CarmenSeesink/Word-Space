//
//  ScoreBoardViewController.swift
//  NiceOff
//
//  Created by Paul Loots on 2019/10/08.
//  Copyright © 2019 Paul Loots. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import UICircularProgressRing
import EFCountingLabel
import NVActivityIndicatorView
import Firebase

class ScoreBoardViewController: UIViewController {

    //Player Data
    var enteredSentence = "I am super happy"
    var answerTime = 0
    var playerScore = 0
    @IBOutlet weak var sentenceLabel: UILabel!
    @IBOutlet weak var scoreLabel: EFCountingLabel!
    @IBOutlet weak var wordBubble: UIView!
    @IBOutlet var roundLabel: UILabel!
    @IBOutlet var catagoryIcon: UIImageView!
    @IBOutlet var currentStatsView: UIView!
    var scoreCalculated = false
    @IBOutlet var playerAvatarImage: UIImageView!
    
    //Timer
    var timer = Timer()
    @IBOutlet var nextRoundButton: DesignableButton!
    
    //Score
    @IBOutlet weak var scoreRing: UICircularProgressRing!
    @IBOutlet weak var scoreLoadingView: NVActivityIndicatorView!
    
    //Colour
     var accentColour = "Purple-Accent"
     var backgroundColour = "Purple-Background"
    
    //Table
    @IBOutlet var resultsTableView: UITableView!
    var players : Array<ScoreItem> = []
    var likedSentenceTags: [Int] = []
    @IBOutlet var resultsView: UIView!
    var isShowingLeaderboard = false
    
    //Loading
    @IBOutlet var nextRoundLoading: NVActivityIndicatorView!
    
    //Models
    let currentGame = Game(passPhrase: "", catagory: "Joy", currentRound: 0, currentRoundCatagory: "", id: Api.User.currentUserId)
    
    //Received Data
    var countDownSeconds = 30
    var currentRound = 1
    var catagory = "Joy"
    var gameID = ""
    var gameAction = "new"
    var passPhrase = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setTheme()
        
        sentenceLabel.text = enteredSentence
        scoreLoadingView.startAnimating()
        animateIn()
        getToneValue(sentenceString:enteredSentence)
        startTimer()
        
        if gameAction != "new" {
            nextRoundButton.backgroundColor = .clear
            nextRoundButton.setTitleColor(UIColor.init(named: accentColour), for: .normal)
        }
        
        nextRoundButton.isUserInteractionEnabled = false
    }
    
    func setTheme() {
        view.tintColor = UIColor.init(named: accentColour)
        view.backgroundColor = UIColor.init(named: backgroundColour)
        nextRoundButton.backgroundColor = UIColor.init(named: self.accentColour)
        scoreRing.innerRingColor = UIColor.init(named: self.accentColour) ?? .black
        var avatarIndex = "0"
        
        if let index = UserDefaults.standard.string(forKey: CURRENT_AVATAR_INDEX){
            avatarIndex = index
        } else {
            UserDefaults.standard.set("0", forKey: CURRENT_AVATAR_INDEX)
        }
        let currentAvatar = avatars[Int(avatarIndex) ?? 0]
        
        //Images
        playerAvatarImage.image = UIImage.init(named: currentAvatar.icon)
    }
    
    //MARK: - Exit Game
    
    func exitGame() {
        removeListners()
        deleteGame()
        self.view.window!.rootViewController?.dismiss(animated: true, completion: nil)
    }
    
    //MARK: - Calculate Score
    
    func calculateScore(angerValue: Float, fearValue: Float, joyValue: Float, sadnessValue: Float) {
        var score: Float = 0
        // TODO: - Replace with DB value
        let currentEmotion = "Joy"
        switch currentEmotion {
        case "Anger":
            score = angerValue - ((fearValue + joyValue + sadnessValue) * 0.6 )
        case "Fear":
            score = fearValue - ((angerValue + joyValue + sadnessValue) * 0.6 )
        case "Joy":
            score = joyValue - ((fearValue + angerValue + sadnessValue) * 0.6 )
        case "Sadness":
            score = sadnessValue - ((fearValue + joyValue + angerValue) * 0.6 )
        default:
            break
        }
        score = Float((Double(answerTime) * 0.01) + (Double(score) * 0.9))
        playerScore = Int(score * 10000)
        displayScore()
        addSentence()
        listenForGame()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.displaySentenceBoard()
        }
    }
    
    //MARK: - Next Round
    
    @IBAction func nextRoundTapped(_ sender: Any) {
        nextRoundButton.setTitle("", for: .normal)
        nextRoundButton.isUserInteractionEnabled = false
        if currentGame.currentRound != 4 {
            nextRoundLoading.startAnimating()
        }
        let documentData = [
            GAME_CURRENT_ROUND: FieldValue.increment(Int64(1))
            ] as [String : Any]
        Api.Game.setGame(documentData: documentData, onSuccess: {
            self.nextRoundLoading.stopAnimating()
        }, onError: {error in
            print(error)
            self.nextRoundButton.setTitle("Error Going to Next Round", for: .normal)
            self.nextRoundButton.isUserInteractionEnabled = true
            self.nextRoundLoading.stopAnimating()
        })
    }
    
    func beginNextRound() {
        if currentGame.currentRound > 4 {
            exitGame()
        } else {
            self.nextRoundButton.setTitle("Next Round in 2", for: .normal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.nextRoundButton.setTitle("Next Round in 1", for: .normal)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.performSegue(withIdentifier: "nextRoundSegue", sender: nil)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        removeListners()
        if segue.identifier == "nextRoundSegue" {
            if let PlaySceneViewController = segue.destination as? PlaySceneViewController {
                PlaySceneViewController.currentRound = currentGame.currentRound
                PlaySceneViewController.catagory = currentGame.catagory
                PlaySceneViewController.gameID = currentGame.id
                PlaySceneViewController.gameAction = gameAction
                PlaySceneViewController.passedPassPhrase = passPhrase
                PlaySceneViewController.accentColour = accentColour
                PlaySceneViewController.backgroundColour = backgroundColour
            }
        }
    }
    
    //MARK: - Like Sentence
    
    @objc func likeSentence(_ sender: UIButton) {
        print("likeTapped")
        self.likedSentenceTags.append(sender.tag)
        self.resultsTableView.reloadData()
        Api.Game.likeSentence(sentenceID: players[sender.tag].playerID + String(currentRound), gameID: gameID, onSuccess: {

        }, onError: {error in print(error)})
    }
    
    // MARK: - Countdown Timer
    
    func startTimer() {
        countDownSeconds = countDownSeconds + 3
         timer = Timer.scheduledTimer(timeInterval: 1, target: self,   selector: (#selector(self.updateTimer)), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        countDownSeconds -= 1
        nextRoundButton.setTitle("Waiting \(countDownSeconds)s", for: .normal)
        
        if countDownSeconds < 1 {
            timer.invalidate()
            showScoreboard()
        }
    }
    
    //MARK: - Scoreboard
    
    func checkCompletedAmount() {
        var completedAmount = 0
        for player in players {
            if player.sentence != "none" {
                completedAmount += 1
            }
        }
        if completedAmount == players.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if !self.isShowingLeaderboard {
                    self.timer.invalidate()
                    self.showScoreboard()
                }
            }
        }
    }
    
    func showScoreboard() {
        isShowingLeaderboard = true
        players = bubbleSortPlayers(players)
        displayScoreboard()
    }
    
    func bubbleSortPlayers(_ array: [ScoreItem]) -> [ScoreItem] {
        if array.count > 1 {
            var arr = array
            for _ in 0...arr.count {
                for value in 1...arr.count - 1 {
                    if arr[value-1].totalScore < arr[value].totalScore {
                        let largerValue = arr[value-1]
                        arr[value-1] = arr[value]
                        arr[value] = largerValue
                    }
                }
            }
            return arr
        }
        return array
    }
    
    // MARK: - Ai Request
    
    func getToneValue(sentenceString:String) {
        guard let correctedSentence = sentenceString.addingPercentEncoding(withAllowedCharacters: .symbols) else {
        print("Error. cannot cast name into String")
        return
        }
        
        let apiKey = "Qa2dXZ3ZDFZ-uMFmjsu3TJIQMnel0GJFIUNGgCAkwkn0"
        let urlString = "https://gateway-lon.watsonplatform.net/tone-analyzer/api/v3/tone?version=2016-05-19&sentences=false&text=\(correctedSentence)"
        
        let url = URL(string: urlString)
        
        Alamofire.request(url!)
        .authenticate(user: "apiKey", password: apiKey)
//            .validate()
            .responseJSON { (response) in
                switch response.result {
                case.success(let value):
                    let json = JSON(value)
                        //print(json)
                    var angerVaue: Float = 0.0
                    var fearVaue: Float = 0.0
                    var joyVaue: Float = 0.0
                    var sadnessVaue: Float = 0.0
                    
                    for n in 0...4 {
                        //print(json["document_tone"]["tone_categories"][0]["tones"])
                        let toneName = json["document_tone"]["tone_categories"][0]["tones"][n]["tone_name"].rawString()
                        let toneScore = json["document_tone"]["tone_categories"][0]["tones"][n]["score"].rawString()
                        switch toneName {
                        case "Anger":
                            angerVaue = (toneScore as NSString?)?.floatValue ?? 0
                        case "Fear":
                            fearVaue = (toneScore as NSString?)?.floatValue ?? 0
                        case "Joy":
                            joyVaue = (toneScore as NSString?)?.floatValue ?? 0
                        case "Sadness":
                            sadnessVaue = (toneScore as NSString?)?.floatValue ?? 0
                        default:
                            break
                        }
                    }
  
                    if !self.scoreCalculated {
                        self.scoreCalculated = true
                        self.calculateScore(angerValue: angerVaue, fearValue: fearVaue, joyValue: joyVaue, sadnessValue: sadnessVaue)
                    }
                    
                case.failure(let error):
                    print(error.localizedDescription)
                    //ProgressHUD.showError(error.localizedDescription)
                }
        }
    }
    
    // MARK: - API
    
    //Game
    func listenForGame() {
        Api.Game.getGame(passPhrase: passPhrase, onSuccess: { (data) in
            self.currentGame.passPhrase = data.passPhrase
            self.currentGame.catagory = data.catagory
            self.currentGame.currentRound = data.currentRound
            self.currentGame.currentRoundCatagory = data.currentRoundCatagory
            self.currentGame.id = data.id
            if self.currentGame.currentRound > self.currentRound {
                self.beginNextRound()
            }
        }, onNotFound: {
            //TODO: - Pop to root
        }, onError: {
            //TODO: - Pop to root
        })
    }
    
    // Sentence
    func setSentenceDocument() -> [String : Any] {
        let documentData = [
            SENTENCE_PLAYERID: Api.User.currentUserId,
            SENTENCE_SCORE: playerScore,
            SENTENCE_LIKES: 0,
            SENTENCE_ROUNDS: currentRound,
            SENTENCE_CATAGORY: catagory,
            SENTENCE_TEXT: enteredSentence
            ] as [String : Any]
        return documentData
    }
    
    func addSentence() {
        Api.Game.addSentence(sentenceID: Api.User.currentUserId + String(currentRound), documentData: setSentenceDocument(), gameID: gameID, onSuccess: {
            self.listenForScoreItems(gameID: self.gameID)
        }, onError: {error in print(error)})
    }
    
    func deleteGame() {
        Api.Game.deleteGame(onSuccess: {}, onError: {error in print(error)})
    }
    
    func listenForScoreItems(gameID: String) {
        Api.Game.getScoreItems(gameID: gameID, currentRound: currentRound, onSuccess: { (data) in
            self.players = []
            self.players = data
            if self.players.count < 1 {
                print("Game Ended")
                self.removeListners()
                return
            }
            self.players = self.bubbleSortPlayers(self.players)
            self.resultsTableView.reloadData()
        }, onGameEnded: {
            print("Game Ended")
        })
    }
    
    func removePlayer(gameID: String) {
        Api.Game.removePlayerFromGame(gameID: gameID, onSuccess: {})
    }
    
    //Observalbles
    func removeListners() {
        Api.Game.removeGetScoreItemsObservers()
        Api.Game.removeGetGameObservers()
    }
    
    //AI

    func approveWord(word: String, catagory: String) {
        Api.AI.getToneValue(catagory: catagory, sentenceString: word, onSuccess: { wordItem in
            print(wordItem.joyValue)
            var addTone = "Joy"
            
            let angerValue = wordItem.angerValue
            let fearValue = wordItem.angerValue
            let joyValue = wordItem.angerValue
            let sadnessValue = wordItem.angerValue
            
            print("Anger: \(angerValue)")
            print("Fear: \(fearValue)")
            print("Sadness: \(joyValue)")
            print("Joy: \(sadnessValue)")
            
            if angerValue > fearValue && angerValue > joyValue && angerValue > sadnessValue {
                addTone = "Anger"
            } else if fearValue > angerValue && fearValue > joyValue && fearValue > sadnessValue {
                addTone = "Fear"
            } else if sadnessValue > fearValue && sadnessValue > joyValue && sadnessValue > angerValue {
                addTone = "Sadness"
            } else {
                addTone = "Joy"
            }
            
//            self.addGameWord(catagory: wordItem.catagory, emotion: addTone, word: wordItem.word)
//            self.removeWord(word: wordItem.word)
        }, onError: {error in print(error)})
    }
    
    // MARK: - Animations
    
    func animateIn() {
        wordBubble.transform = .init(translationX: -50, y: 0)
        wordBubble.alpha = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut, animations: {
                self.wordBubble.transform = .identity
                self.wordBubble.alpha = 1
            })
        }
    }
    
    func displayScore() {
        scoreLoadingView.stopAnimating()
        scoreRing.isHidden = false
        
        scoreLabel.setUpdateBlock { value, label in
            let intValue = Int(value)
            label.text = intValue.formattedWithSeparator
        }
        scoreLabel.counter.timingFunction = EFTimingFunction.easeOut(easingRate: 2)
        scoreLabel.countFrom(0, to: CGFloat(playerScore) , withDuration: 1.5)
        
        scoreRing.animationTimingFunction = .easeOut
        if playerScore < 0 {
            let score = -playerScore
            scoreRing.isClockwise = false
            scoreRing.startProgress(to: CGFloat(score/100), duration: 1.5)
        } else {
            scoreRing.startProgress(to: CGFloat(playerScore/100), duration: 1.5)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
                self.scoreLabel.transform = .init(scaleX: 1.2, y: 1.2)
            })
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                self.scoreLabel.transform = .identity
            })
        }
    }
    
    func displaySentenceBoard() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.currentStatsView.transform = .init(translationX: 0, y: -300)
            self.currentStatsView.alpha = 0
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                self.currentStatsView.isHidden = true
            })
        }
        self.resultsView.transform = .init(translationX: 0, y: 300)
        self.resultsView.alpha = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.resultsView.isHidden = false
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.resultsView.transform = .identity
                self.resultsView.alpha = 1
            })
        }
    }
    
    func displayScoreboard() {
        if gameAction == "new" {
            self.nextRoundButton.setTitle("Next Round", for: .normal)
            self.nextRoundButton.isUserInteractionEnabled = true
        } else {
            self.nextRoundButton.setTitle("Waiting for next Round", for: .normal)
        }
        if currentRound > 3 {
            self.nextRoundButton.setTitle("End Game", for: .normal)
        }
        self.currentStatsView.isHidden = true
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.resultsView.transform = .init(translationX: 0, y: -300)
            self.resultsView.alpha = 0
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.resultsView.transform = .init(translationX: 0, y: 300)
            self.resultsView.alpha = 0
            self.resultsTableView.reloadData()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.resultsView.isHidden = false
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.resultsView.transform = .identity
                self.resultsView.alpha = 1
            })
        }
    }
}

// MARK: - Extentions

extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = " "
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension Int{
    var formattedWithSeparator: String {
        return Formatter.withSeparator.string(for: self) ?? ""
    }
}

// MARK: - Table View Delegates

extension ScoreBoardViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return players.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isShowingLeaderboard {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreboardTableViewCell", for: indexPath) as! ScoreboardTableViewCell
            
            if players[indexPath.row].playerID == Api.User.currentUserId {
                cell.name.text = "Me"
            } else {
                cell.name.text = players[indexPath.row].playerName
            }
            let currentAvatar = avatars[Int(players[indexPath.row].playerAvatar) ?? 0]
            cell.avatar.image = UIImage.init(named: currentAvatar.icon)
            cell.planetImage.image = UIImage.init(named: currentAvatar.background)
            cell.planetImage.tintColor = UIColor.init(named: currentAvatar.colour + "-Background")
            cell.place.text = String(indexPath.item + 1)
            cell.place.textColor = UIColor.init(named: currentAvatar.colour + "-Accent")
            cell.score.text = String(players[indexPath.row].totalScore)
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RoundScoreTableViewCell", for: indexPath) as! RoundScoreTableViewCell
            
            if players[indexPath.row].playerID == Api.User.currentUserId {
                self.likedSentenceTags.append(indexPath.row)
                cell.playerName.text = "Me"
            } else {
                cell.playerName.text = players[indexPath.row].playerName
            }
            let currentAvatar = avatars[Int(players[indexPath.row].playerAvatar) ?? 0]
            cell.playerImage.image = UIImage.init(named: currentAvatar.icon)
            cell.sentenceScore.text = String(players[indexPath.row].sentenceScore)
            if likedSentenceTags.contains(indexPath.row) {
                cell.likeButton.isEnabled = false
                cell.likeIcon.alpha = 0.5
            } else {
                cell.likeButton.tag = indexPath.row
                cell.likeButton.addTarget(self,  action: #selector(likeSentence), for: .touchUpInside)
            }
            if players[indexPath.row].likes > 0 {
                cell.likeCount.text = String(players[indexPath.row].likes)
                cell.likeIcon.transform = .identity
            } else {
                cell.likeCount.text = ""
                cell.likeIcon.transform = .init(translationX: 0, y: 12)
            }
            if players[indexPath.row].sentence == "none" {
                cell.sentenceLabel.text = ""
                cell.typingIndicator.color = UIColor.init(named: currentAvatar.colour + "-Accent") ?? .black
                cell.likeBackground.backgroundColor = UIColor.init(named: "Text-Primary")
                cell.likeBackground.alpha = 0.1
                cell.typingIndicator.startAnimating()
            } else {
                cell.likeBackground.alpha = 1
                cell.likeBackground.backgroundColor = UIColor.init(named: currentAvatar.colour + "-Accent")
                cell.sentenceLabel.text = players[indexPath.row].sentence
                cell.typingIndicator.stopAnimating()
            }
            
            self.checkCompletedAmount()
            
            return cell
        }
    }
    
}
