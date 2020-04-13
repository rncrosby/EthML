//
//  ViewController.swift
//  ethML
//
//  Created by Robert Crosby on 4/9/20.
//  Copyright © 2020 Robert Crosby. All rights reserved.
//

import UIKit

struct Point {
    var prediction: Double
    var open: Double
    var cap: Double
    var value_change: Double
    var volume_change: Double
    var cap_change: Double
    var onehour: Double
    var oneday: Double
    var sevenday: Double
    var thirtyday: Double
    
}

class ViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,ModelProtocol {
    
    var predictionColor:UIColor?
    var model = ModelBuilder()
    var current:Point?
    var table:UITableView
    var scrollIndicator:UIImageView?
    
    init() {
        self.table = UITableView.init()
        self.table.backgroundColor = .clear
        super.init(nibName: nil, bundle: nil)
        self.view.backgroundColor = .systemBackground
        self.table.frame = self.view.bounds
        self.table.clipsToBounds = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.table = UITableView()
       super.init(coder: aDecoder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidLoad() {
        
        model.delegate = self
        let refresh = UIRefreshControl()
        let rtitle = NSAttributedString.init(string: "RELOAD PRICE", attributes: [NSAttributedString.Key.font : UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
        
        refresh.attributedTitle = rtitle
        refresh.addTarget(self, action: #selector(reloadPrice(sender:)), for: .valueChanged)
        self.navigationController?.navigationBar.isHidden = true
        self.table.delegate = self
        self.table.refreshControl = refresh
        self.table.dataSource = self
        self.table.separatorStyle = .none
        self.table.backgroundColor = .clear
        self.table.showsVerticalScrollIndicator = false
//        self.table.scrollIndicatorInsets = UIEdgeInsets.init(top: self.view.safeAreaInsets.top+240+200+108, left: 0, bottom: 0, right: 0)
        self.view.addSubview(self.table)
        super.viewDidLoad()
        model.initializeModel()
        
        // Do any additional setup after loading the view.
    }
    
    func initializePrediction() {
        getCurrentPrice { (success) in
            if success {
                print("done with current price")
            } else {
                print("error fetching current price")
            }
            self.model.initializeHistoricalData()
        }
    }
    
    func localModelPrepared() {
        print("local model ready")
        
        initializePrediction()
    }
    
    func remoteModelPrepared() {
        print("remote model ready")
        initializePrediction()
    }
    
    func historicalDataPrepared() {
        DispatchQueue.main.async {
            self.table.reloadData()
            if self.isReloadingHistory {
                self.isReloadingHistory = false
                self.table.reloadData()
                UIView.animate(withDuration: 0.5, animations: {
                    self.table.frame.origin.y = 0
                    self.table.alpha = 1
                    self.updating?.alpha = 0
                }) { (done) in
                    if done {
                        self.updating?.removeFromSuperview()
                        self.updating = nil
                        self.table.isUserInteractionEnabled = true
      
                    }
                    
                }
            }
            
        }
    }
    var isReloadingModel = false
    var isReloadingHistory = false
    var updating:UILabel?
    
    func updatingLabel(_ message: String) {
        updating = UILabel.init(frame: CGRect.init(origin: CGPoint.init(x: 0, y: self.view.safeAreaInsets.top+20), size: CGSize.init(width: self.view.frame.size.width, height: 50)))
        updating?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        updating?.textColor = .label
        updating?.textAlignment = .center
        updating?.text = message
        updating?.alpha = 0
        self.view.addSubview(updating!)
        self.view.sendSubviewToBack(updating!)
    }
    
    @objc func startUpdateModel() {
        self.table.isUserInteractionEnabled = false
        self.isReloadingModel = true
        updatingLabel("RETRAINING MODEL")
        UIView.animate(withDuration: 0.5, animations: {
            self.table.frame.origin.y = self.updating!.frame.maxY+20
            self.table.alpha = 0.25
            self.updating?.alpha = 1
        }) { (finished) in
            if finished {
                self.model.updateModel(url: "https://github.com/rncrosby/rncrosby.github.io/raw/master/eth/latest.mlmodel")
            }
        }
        
        
    }
    
    @objc func startUpdateHistory() {
        self.table.isUserInteractionEnabled = false
        self.isReloadingHistory = true
        updatingLabel("UPDATING HISTORY")
        UIView.animate(withDuration: 0.5, animations: {
            self.table.frame.origin.y = self.updating!.frame.maxY+20
            self.table.alpha = 0.25
            self.updating?.alpha = 1
        }) { (finished) in
            if finished {
                self.model.updateHistoricalData()
//                self.model.updateModel(url: "https://github.com/rncrosby/rncrosby.github.io/raw/master/eth/latest.mlmodel")
            }
        }
    }
    
    var navblur:UIVisualEffectView?
    var headerBlurIsVisible = false
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        if offset > 0 && navblur == nil {
            navblur = UIVisualEffectView.init(effect: UIBlurEffect.init(style: .systemChromeMaterial))
            navblur?.frame = CGRect.init(origin: CGPoint.zero, size: CGSize.init(width: self.view.frame.size.width, height: self.view.safeAreaInsets.top))
            
            navblur?.alpha = 0
            self.view.addSubview(navblur!)
            UIView.animate(withDuration: 0.25) {
                self.navblur?.alpha = 1
            }
        } else if offset >= ((table.rectForHeader(inSection: 1).origin.y)-self.view.safeAreaInsets.top) && !headerBlurIsVisible {
            headerBlurIsVisible = true
            UIView.animate(withDuration: 0.25) {
                self.headerEffectView?.alpha = 1
            }
        } else if offset < ((table.rectForHeader(inSection: 1).origin.y)-self.view.safeAreaInsets.top) && headerBlurIsVisible {
            
            headerBlurIsVisible = false
            UIView.animate(withDuration: 0.25) {
                self.headerEffectView?.alpha = 0
            }
        } else if offset <= 0 && navblur != nil {
            UIView.animate(withDuration: 0.25, animations: {
                self.navblur?.alpha = 0
            }) { (finished) in
                if finished {
                    self.navblur = nil
                }
            }
        }
    }
    
    @objc func reloadPrice(sender: UIRefreshControl) {
        getPrice { (response) in
            if let result = response {
                let oneHour = result["1h"] as! NSDictionary
                let oneHourPriceChange = (oneHour["price_change"] as! NSString).doubleValue
                let oneDay = result["1d"] as! NSDictionary
                let oneDayPriceChange = (oneDay["price_change"] as! NSString).doubleValue
                let sevenDay = result["7d"] as! NSDictionary
                let sevenDayPriceChange = (sevenDay["price_change"] as! NSString).doubleValue
                let thirtyDay = result["30d"] as! NSDictionary
                let thirtyDayPriceChange = (thirtyDay["price_change"] as! NSString).doubleValue
                let capChange = (oneDay["market_cap_change_pct"] as! NSString).doubleValue
                let priceChange = (oneDay["price_change_pct"] as! NSString).doubleValue
                let volumeChange = (oneDay["volume_change_pct"] as! NSString).doubleValue
                let cap = (result["market_cap"] as! NSString).doubleValue
                let price = (result["price"] as! NSString).doubleValue
                let prediction = self.model.makePrediction(open: price, cap: cap, priceChange: priceChange, volumeChange: volumeChange, capChange: capChange)
                self.current = Point.init(prediction: prediction!, open: price, cap: cap, value_change: priceChange, volume_change: volumeChange, cap_change: capChange,onehour: oneHourPriceChange, oneday: oneDayPriceChange, sevenday: sevenDayPriceChange, thirtyday: thirtyDayPriceChange)
//                    self.getHistoricalData(refresh: true)
                DispatchQueue.main.async {
                    self.table.reloadData()
                    sender.endRefreshing()
                }
            } else {
                print("No response?")
            }
            
        }
    }
    
    var loaded = false
    
    func getCurrentPrice(completion: @escaping (Bool) -> ()) {
        getPrice { (response) in
            if let result = response {
                let oneHour = result["1h"] as! NSDictionary
                let oneHourPriceChange = (oneHour["price_change"] as! NSString).doubleValue
                let oneDay = result["1d"] as! NSDictionary
                let oneDayPriceChange = (oneDay["price_change"] as! NSString).doubleValue
                let sevenDay = result["7d"] as! NSDictionary
                let sevenDayPriceChange = (sevenDay["price_change"] as! NSString).doubleValue
                let thirtyDay = result["30d"] as! NSDictionary
                let thirtyDayPriceChange = (thirtyDay["price_change"] as! NSString).doubleValue
                let capChange = (oneDay["market_cap_change_pct"] as! NSString).doubleValue
                let priceChange = (oneDay["price_change_pct"] as! NSString).doubleValue
                let volumeChange = (oneDay["volume_change_pct"] as! NSString).doubleValue
                let cap = (result["market_cap"] as! NSString).doubleValue
                let price = (result["price"] as! NSString).doubleValue
                let prediction = self.model.makePrediction(open: price, cap: cap, priceChange: priceChange, volumeChange: volumeChange, capChange: capChange)
                if prediction != nil {
                    self.current = Point.init(prediction: prediction!, open: price, cap: cap, value_change: priceChange, volume_change: volumeChange, cap_change: capChange,onehour: oneHourPriceChange, oneday: oneDayPriceChange, sevenday: sevenDayPriceChange, thirtyday: thirtyDayPriceChange)
                } else {
                    self.current = Point.init(prediction: price, open: price, cap: cap, value_change: priceChange, volume_change: volumeChange, cap_change: capChange,onehour: oneHourPriceChange, oneday: oneDayPriceChange, sevenday: sevenDayPriceChange, thirtyday: thirtyDayPriceChange)
                }
                DispatchQueue.main.async {
                    if !self.loaded {
                        self.loaded = true
                        self.table.beginUpdates()
                        self.table.insertRows(at: [IndexPath.init(row: 0, section: 0), IndexPath.init(row: 1, section: 0)], with: .fade)
                        self.table.endUpdates()
                        completion(true)
                    } else {
                        if self.isReloadingModel {
                            self.isReloadingModel = false
                            self.table.reloadData()
                            UIView.animate(withDuration: 0.5, animations: {
                                self.table.frame.origin.y = 0
                                self.table.alpha = 1
                                self.updating?.alpha = 0
                            }) { (done) in
                                if done {
                                    self.updating?.removeFromSuperview()
                                    self.updating = nil
                                    self.table.isUserInteractionEnabled = true
                                    completion(true)
                                }
                                
                            }
                        }
                        
                    }
                }
            } else {
                print("No response?")
                completion(false)
            }
            
        }
    }
    
    func getPrice(completion: @escaping (NSDictionary?) -> ())  {
        let url = URL(string: "https://api.nomics.com/v1/currencies/ticker?key=7195a4c7b0e42d794aa2d9ac4d00240b&ids=ETH&interval=1h,1d,7d,30d&convert=USD")
        guard let requestUrl = url else { fatalError() }
        // Create URL Request
        var request = URLRequest(url: requestUrl)
        // Specify HTTP Method to use
        request.httpMethod = "GET"
        // Send HTTP Request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
    
            // Check if Error took place
            if let error = error {
                print("Error took place \(error)")
                completion(nil)
                return
            }
    
            // Read HTTP Response Status code
            if let response = response as? HTTPURLResponse {
                print("Response HTTP Status code: \(response.statusCode)")
            }
            do {
                
                if let result = try JSONSerialization.jsonObject(with: data!, options: [.allowFragments]) as? NSArray {
                    if let res = result.firstObject as? NSDictionary {
                        completion(res)
                    }
//                    let resp = result["USD"] as! NSNumber
//                    print(resp)
//                    completion(Date().timeIntervalSince1970, resp.doubleValue)
                }
            } catch let error as NSError {
                print(error.localizedDescription)
                completion(nil)
                return
            }
        }
        task.resume()
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 1:
            return model.predictions.isEmpty ? 0 : 128
        default:
            return 0
        }
    }
    
    var headerEffectView:UIVisualEffectView?
    var border:CALayer?
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 && !self.model.predictions.isEmpty {
            let view = UIView.init(frame: CGRect.init(origin: CGPoint.zero, size: CGSize.init(width: tableView.frame.size.width, height: 128)))
            headerEffectView = UIVisualEffectView.init(effect: UIBlurEffect.init(style: .systemChromeMaterial))
            headerEffectView?.alpha = 0
            headerEffectView?.frame = view.bounds
            border = CALayer()
            border?.frame = CGRect.init(x: 0, y: view.frame.size.height-1, width: view.frame.size.width, height: 1)
            border?.backgroundColor = UIColor.separator.cgColor
            headerEffectView?.layer.addSublayer(border!)
            view.addSubview(headerEffectView!)
//
//            let title = UILabel.init(frame: CGRect.init(origin: CGPoint.init(x: 0, y: 20), size: CGSize.init(width: tableView.frame.size.width, height: 24)))
//            title.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
//            title.text = "Past Predictions"
//            title.textAlignment = .center
//            title.textColor = .label
//            view.addSubview(title)
            let updateHistory = UIButton.init(frame: CGRect.init(origin: CGPoint.init(x: 0, y: 20), size: CGSize.init(width: tableView.frame.size.width, height: 30)))
            let needUpdate = self.checkLastTimeUpdated(type: "history")
            if needUpdate.0 {
                updateHistory.setTitle("UPDATE HISTORY", for: .normal)
                updateHistory.addTarget(self, action: #selector(startUpdateHistory), for: .touchUpInside)
            } else {
                updateHistory.addTarget(self, action: #selector(startUpdateHistory), for: .touchUpInside)

                updateHistory.setTitle("HISTORY", for: .normal)
            }
            updateHistory.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            updateHistory.setTitleColor(.label, for: .normal)
            view.addSubview(updateHistory)
            let lastupdate = UILabel.init(frame: CGRect.init(x: 40, y: updateHistory.frame.maxY, width: view.frame.size.width-80, height: 20))
            lastupdate.text = needUpdate.1
            lastupdate.font = .monospacedSystemFont(ofSize: 8, weight: .regular)
            lastupdate.textAlignment = .center
            lastupdate.textColor = .systemGray2
            view.addSubview(lastupdate)
            let width = ((self.view.frame.size.width-20)/4)
            for (index,title) in ["","open","pred.","actual"].enumerated() {
                let label = UILabel.init(frame: CGRect.init(origin: CGPoint.init(x: 20+(Int(width)*index), y: 44+20+20), size: CGSize.init(width: width, height: 24)))
                    label.textAlignment = .left
                
                label.text = title
                label.textColor = .systemGray2
                label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                view.addSubview(label)
            }
            
            return view
        }
        return nil
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if !isReloadingModel && !isReloadingHistory && current != nil {
            self.table.beginUpdates()
            self.table.reloadRows(at: [IndexPath.init(row: 1, section: 0)], with: .fade)
            self.border?.backgroundColor = UIColor.separator.cgColor
            self.table.endUpdates()
        }
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return current != nil ? 2 : 0
        default:
            return model.predictions.count
        }
    }
    
    func checkLastTimeUpdated(type: String) -> (Bool, String) {
        let lastUpdate = UserDefaults.standard.double(forKey: type)
        let difference = Date.init().timeIntervalSinceReferenceDate - lastUpdate
        if difference > 86400 {
            let days = Int(difference / 86400)
            return (true, "\(type) updated \(Int(days)) day\(days > 1 ? "s" : "" ) ago")
        } else if difference > 3600 {
            let hours = Int(difference / 3600)
            return (false, "\(type) updated \(Int(hours)) hour\(hours > 1 ? "s" : "" ) ago")
        } else if difference > 60 {
            let minutes = Int(difference / 60)
            return (false, "\(type) updated \(Int(minutes)) minute\(minutes > 1 ? "s" : "" ) ago")
        } else {
            return (false, "\(type) updated just now")
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell.init(style: .default, reuseIdentifier: "PriceCell")
            cell.backgroundColor = .clear
            cell.clipsToBounds = false
            cell.selectionStyle = .none
            let card = UIView.init(frame: CGRect.init(x: 20, y: 20, width: tableView.frame.size.width-40, height: heightForRow(row: indexPath.row)-30))
            card.layer.shadowColor = UIColor.black.cgColor
            card.layer.shadowOffset = CGSize.init(width: 1, height: 1)
            card.layer.shadowRadius = 15
            card.layer.shadowOpacity = 0.20
            cell.addSubview(card)
            let type = UILabel.init(frame: CGRect.init(origin: CGPoint.init(x: 20, y: 20), size: CGSize.init(width: card.frame.size.width-40, height: 40)))
            type.textAlignment = .center
            type.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            type.textColor = .white
            card.addSubview(type)
            
            let price = UILabel.init(frame: CGRect.init(origin: CGPoint.init(x: 0, y: type.frame.maxY), size: CGSize.init(width: card.frame.size.width, height: 70)))
             price.textAlignment = .center
             price.font = .monospacedSystemFont(ofSize: 56, weight: .regular)
             card.addSubview(price)
             
             switch indexPath.row {
             case 1:
                card.backgroundColor = self.current!.prediction > self.current!.open ? UIColor.systemGreen : UIColor.systemRed
                if traitCollection.userInterfaceStyle == .dark {
                    card.backgroundColor = card.backgroundColor?.withAlphaComponent(0.25)
                }
                 
                 self.predictionColor = card.backgroundColor
                 type.text = "PREDICTION"
                 price.text = "$\(self.current!.prediction.rounded(toPlaces: 2))"
                 price.textColor = .white
                 let updateModel = UIButton.init(frame: CGRect.init(origin: CGPoint.init(x: 0, y: heightForRow(row: indexPath.row)-20-80), size: CGSize.init(width: card.frame.size.width, height: 30)))
                 let modelStatus = checkLastTimeUpdated(type: "model")

                 
//                 if modelStatus.0 {
                    updateModel.addTarget(self, action: #selector(startUpdateModel), for: .touchUpInside)
                 
                 updateModel.setTitle("UPDATE MODEL", for: .normal)
                 updateModel.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                 updateModel.setTitleColor(.white, for: .normal)
                 card.addSubview(updateModel)
                
                 let lastupdate = UILabel.init(frame: CGRect.init(x: 40, y: updateModel.frame.maxY, width: card.frame.size.width-80, height: 20))
                 lastupdate.text = modelStatus.1
                 lastupdate.font = .monospacedSystemFont(ofSize: 8, weight: .regular)
                 lastupdate.textAlignment = .center
                 lastupdate.textColor = .white
                 card.addSubview(lastupdate)
//                let updateHistory = UIButton.init(frame: CGRect.init(origin: CGPoint.init(x: card.frame.size.width/2, y: heightForRow(row: indexPath.row)-20-80), size: CGSize.init(width: card.frame.size.width/2, height: 60)))
//                updateHistory.setTitle("UPDATE HISTORY", for: .normal)
//                updateHistory.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
//                updateHistory.setTitleColor(.white, for: .normal)
//                card.addSubview(updateHistory)
             default:
                 card.backgroundColor = .darkText
                 let dfm = DateFormatter()
                 dfm.dateFormat = "EEEE, MMMM d @ h:mm a"
                 type.text = dfm.string(from: Date())
                 price.text = "$\(self.current!.open.rounded(toPlaces: 2))"
                 price.textColor = .white
                 let oneH = valueChangeLabel(metric: "1H", value: self.current!.onehour, origin: CGPoint.init(x: 0, y: heightForRow(row: indexPath.row)-20-80), size: CGSize.init(width: card.frame.size.width/4, height: 60), color: true, font: nil)
                 let oneD = valueChangeLabel(metric: "1D", value: self.current!.oneday, origin: CGPoint.init(x: oneH.frame.maxX, y: oneH.frame.origin.y), size: oneH.frame.size, color: true, font: nil)
                 let sevenD = valueChangeLabel(metric: "7D", value: self.current!.sevenday, origin: CGPoint.init(x: oneD.frame.maxX, y: oneH.frame.origin.y), size: oneH.frame.size, color: true, font: nil)
                 let thirtyD = valueChangeLabel(metric: "1M", value: self.current!.thirtyday, origin: CGPoint.init(x: sevenD.frame.maxX, y: oneH.frame.origin.y), size: oneH.frame.size, color: true, font: nil)
                 card.addSubview(oneH)
                 card.addSubview(oneD)
                 card.addSubview(sevenD)
                 card.addSubview(thirtyD)
             }
            cell.layer.zPosition = 1
             return cell
        } else {
            
            
            let cell = UITableViewCell.init(style: .default, reuseIdentifier: "HistoricalCell")
            cell.layer.zPosition = -1
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            let line = UIView.init(frame: CGRect.init(x: 0, y: 60-1, width: tableView.frame.size.width, height: 1))
            line.backgroundColor = .separator
            cell.addSubview(historicalCell(index: indexPath.row))
            cell.addSubview(line)
            return cell
        }
        
    }
    
    var expanded:IndexPath?
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            let height = heightForRow(row: indexPath.row)
            return height
//            return indexPath.row == 0 ? height : height+self.view.safeAreaInsets.top
        default:
            if indexPath == expanded {
                return 120
            }
            return 60
            
        }
        
    }
    
    func heightForRow(row: Int) -> CGFloat {
        
        return 240
    }

    func historicalCell(index: Int) -> UIView {
        let prediction = self.model.predictions[index]
        let view = UIView.init(frame: CGRect.init(origin: CGPoint.zero, size: CGSize.init(width: self.view.frame.size.width, height: 120)))
        view.backgroundColor = .clear
//        let dfm = DateFormatter.init()
//        dfm.dateFormat = "M/d/YY"
//        let d = dfm.date(from: self.historical[index].date)
//        dfm.dateFormat = "MMM d"
        let width = ((self.view.frame.size.width-20)/4)
        let date = valueChangeLabel(metric: String(prediction.date.replacingOccurrences(of: "\"", with: "").split(separator: ",")[0]), value: nil, origin: CGPoint.init(x: 20, y: 0), size: CGSize.init(width: width, height: 60), color: false, font: nil)
        date.textColor = .label
        date.textAlignment = .left
        view.addSubview(date)
        
        let error = withinPercentError(predict: prediction.predicted, actual: prediction.actual)
        for (index,value) in [prediction.open,prediction.predicted,prediction.actual].enumerated() {
            let label = UILabel.init(frame: CGRect.init(origin: CGPoint.init(x: 20+(Int(width)*(index+1)), y: 0), size: CGSize.init(width: width, height: 60)))
            
            if index == 3 {
                let score = Int(100-value.rounded(toPlaces: 0))
                label.text = "\(score)"
                label.textColor = .systemGreen
            } else {
                label.text = valueChangeToDollar(value: value)
                label.textColor = .label
            }
            label.textAlignment = .left
            
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            view.addSubview(label)
        }
        return view
    }
    
    func drawLine(origin: CGPoint, distance: CGFloat, slope: CGFloat, color: UIColor) -> CAShapeLayer {
        let path = UIBezierPath.init()
        path.move(to: origin)
        path.addLine(to: CGPoint.init(x: origin.x+distance, y: origin.y+slope))
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.lineCap = .square
        shapeLayer.lineDashPattern = [5,10]
        return shapeLayer
    }
    
    func valueChangeLabel(metric: String, value: Double?, origin: CGPoint, size: CGSize, color: Bool, font: UIFont?) -> UILabel {
        let label = UILabel.init(frame: CGRect.init(origin: origin, size: size))
        label.font = font ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.textColor = .black
        label.numberOfLines = 2
        if value != nil {
            label.text = "\(metric)\n\(valueChangeToDollar(value: value!))"
        } else {
            label.text = metric
        }
        if color {
            if value! > 0 {
                label.textColor = .systemGreen
            } else if value! < 0 {
                label.textColor = .systemRed
            }
        }
        return label
    }
    
    func withinPercentError(predict: Double, actual: Double) -> (Double, Bool) {
        let error = (abs(predict-actual)/actual)*100
        return (error, (error > -5 && error < 5))
    }
    
    func valueChangeToDollar(value: Double) -> String {
        if value < 0 {
            return "-$\(abs(value.rounded(toPlaces: 2)))"
        }
        return "$\(abs(value.rounded(toPlaces: 2)))"
    }
    
}

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
