//
//  Downloader.swift
//  ethML
//
//  Created by Robert Crosby on 4/12/20.
//  Copyright © 2020 Robert Crosby. All rights reserved.
//

import UIKit
import Foundation
import CoreML

struct HistoricalPrediction {
    var date: String
    var open: Double
    var actual: Double
    var predicted: Double
}

protocol ModelProtocol: class {
    func localModelPrepared()
    func remoteModelPrepared()
    func historicalDataPrepared()
}

class ModelBuilder: NSObject {
    
    weak var delegate:ModelProtocol?
    var model:MLModel?
    var predictions = [HistoricalPrediction]()
    
    override init() {
        super.init()
    }
    
    func initializeModel() {
            // check tmp (sim runs in doc, physical saves in tmp?)
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("(A Document Being Saved By ethML)", isDirectory: true).appendingPathComponent("latest.mlmodelc", isDirectory: false)
            if FileManager.default.fileExists(atPath: tmp.path) {
                do {
                    self.model = try MLModel(contentsOf: tmp)
                    delegate?.localModelPrepared()
                } catch {
                    print("error training")
                }
                
            } else {
                print("Not in temp, checking documents")
                do {
                    // check tmp (sim runs in doc, physical saves in tmp?)
                    let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    let compiledUrl = documentsURL.appendingPathComponent("(A Document Being Saved By ethML)", isDirectory: true).appendingPathComponent("latest.mlmodelc", isDirectory: false)
                    self.model = try MLModel(contentsOf: compiledUrl)
                    delegate?.localModelPrepared()
                } catch {
                    print("No local model, retrieving it.")
                    updateModel(url: "https://github.com/rncrosby/rncrosby.github.io/raw/master/eth/latest.mlmodel")
                }
            }
    }

    func updateModel(url: String) {
        let url = URL(string: url)!
        let downloadTask = URLSession.shared.downloadTask(with: url) { urlOrNil, responseOrNil, errorOrNil in
            guard let fileURL = urlOrNil else { return }
            do {
                let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let savedURL = documentsURL.appendingPathComponent("latest.mlmodel")
                do {
                    // move existing model
                    try FileManager.default.moveItem(at: savedURL, to: documentsURL.appendingPathComponent("old.mlmodel"))
                    print("Moved existing model")
                } catch {
                    print("Error: No existing model to move")
                }
                do {
                    // rename and move new model
                    try FileManager.default.moveItem(at: fileURL, to: savedURL)
                    print("Renamed and moved new model")
                    // moved new model, delete old
                    do {
                        try FileManager.default.removeItem(atPath: documentsURL.appendingPathComponent("old.mlmodel").path)
                        print("Deleted old model")
                    } catch {
                        print("Error: Couldn't delete old model")
                    }
                } catch {
                    print("Error: Can't new model, will try restoring old model")
                    // resotre old model
                    do {
                        try FileManager.default.moveItem(at: documentsURL.appendingPathComponent("old.mlmodel"), to: savedURL)
                        print("Restored old model")
                    } catch {
                        print("Error: Can't restore old model")
                    }
                }
                do {
                    // delete old model compile
                    try FileManager.default.removeItem(atPath: documentsURL.appendingPathComponent("(A Document Being Saved By ethML)", isDirectory: true).path)
                    print("deleted old compiler")
                } catch {
                    // couldnt delete old one
                }
                self.logUpdate(type: "model")
                let compiledUrl = try MLModel.compileModel(at: savedURL)
                self.model = try MLModel(contentsOf: compiledUrl)
                self.delegate?.remoteModelPrepared()
            } catch {
                print("Couldn't get documents directory")
            }
            
       }
       downloadTask.resume()
    }
    
    func updateHistoricalData() {
        let url = URL(string: "https://raw.githubusercontent.com/rncrosby/rncrosby.github.io/master/eth/history.csv")!
         let downloadTask = URLSession.shared.downloadTask(with: url) { urlOrNil, responseOrNil, errorOrNil in
             guard let fileURL = urlOrNil else { return }
             do {
                 let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                 let savedURL = documentsURL.appendingPathComponent("history.csv")
                 do {
                     // move existing model
                     try FileManager.default.moveItem(at: savedURL, to: documentsURL.appendingPathComponent("old_history.csv"))
                     print("Moved existing history")
                 } catch {
                     print("Error: No existing history to move")
                 }
                 do {
                     // rename and move new model
                     try FileManager.default.moveItem(at: fileURL, to: savedURL)
                     print("Renamed and moved new history")
                     // moved new model, delete old
                     do {
                         try FileManager.default.removeItem(atPath: documentsURL.appendingPathComponent("old_history.csv").path)
                         print("Deleted old history")
                     } catch {
                         print("Error: Couldn't delete old history")
                     }
                 } catch {
                     print("Error: Can't move new history, will try restoring old history")
                     // resotre old model
                     do {
                         try FileManager.default.moveItem(at: documentsURL.appendingPathComponent("old_history.csv"), to: savedURL)
                         print("Restored old history")
                     } catch {
                         print("Error: Can't restore old history")
                     }
                 }
                self.logUpdate(type: "history")
                self.initializeHistoricalData()
             } catch {
                 print("Couldn't get documents directory")
             }
             
        }
        downloadTask.resume()
    }
    
    func initializeHistoricalData() {
            do {
                let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let path = documentsURL.appendingPathComponent("history.csv")
                if FileManager.default.fileExists(atPath: path.path) {
                    print("History found")
                    do {
                        let string = try String(contentsOf: path, encoding: String.Encoding.utf8)
                        let data = string.components(separatedBy: "\n")
                        var count = 0
                        var temp = [HistoricalPrediction]()
                        while count < 20 {
                            count+=1
                            let parsed = data[count].components(separatedBy: ",")
                            let date = "\(parsed[0]),\(parsed[1])"
                            let open = Double.init(parsed[2])
                            let close = Double.init(parsed[3])
    //                        let volume = Double.init(parsed[3])
                            let cap = Double.init(parsed[5])
                            let value_change = Double.init(parsed[6])
                            let volume_change = Double.init(parsed[7])
                            let cap_change = Double.init(parsed[8].replacingOccurrences(of: "\r", with: ""))
                            let prediction = self.makePrediction(open: open!, cap: cap!, priceChange: value_change!, volumeChange: volume_change!, capChange: cap_change!)
                            if (prediction != nil) {
                                 temp.append(HistoricalPrediction.init(date: date, open: open!, actual: close!, predicted: prediction!))
                            }
                        }
                        self.predictions = temp
                        self.delegate?.historicalDataPrepared()
                    } catch {
                        print("something went wrong")
                    }
                } else {
                    print("History not found")
                    print("No local data, retrieving it.")
                    updateHistoricalData()
                }
                
            } catch {
                print("error in docs")
            }
        }
    
    func makePrediction(open: Double, cap: Double, priceChange: Double, volumeChange: Double, capChange: Double) -> Double? {
        do {
            let prediction = try self.model?.prediction(from: MLDictionaryFeatureProvider.init(dictionary:
                [   "open"          : open,
                    "cap"           : cap,
                    "open_change"   : priceChange,
                    "volume_change" : volumeChange,
                    "cap_change"    : capChange
                ]
            ))
            return prediction?.featureValue(for: "close")?.doubleValue
        } catch {
            print("Unable to predict")
            return nil
        }
    }
    
    func logUpdate(type: String) {
        UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: type)
        UserDefaults.standard.synchronize()
    }
}
