//
//  ViewController.swift
//  tfliteExample
//
//  Created by Pavan Gopal on 28/02/19.
//  Copyright © 2019 Pavan Gopal. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMLCommon

class ViewController: UIViewController {
    
    private let modelName:String = "converted_model"
    private let modelType:String = ".tflite"
    private let productListFileName:String = "products"
    
    var userInputData:[[Float]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadModelFromFirebase()
        loadModelFromBundle()
        getInterpreter()
    }
    
    private func loadModelFromFirebase() {
        let conditions = ModelDownloadConditions(isWiFiRequired: true, canDownloadInBackground: true)
        let cloudModelSource = CloudModelSource(name: modelName,
                                                enableModelUpdates: true,
                                                initialConditions: conditions,
                                                updateConditions: conditions)
        
        let registrationSuccessful = ModelManager.modelManager().register(cloudModelSource)
        print(registrationSuccessful)
    }
    
    private func loadModelFromBundle() {
        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: modelType) else {
            debugPrint("Invalid model Path")
            return
        }
        
        let localModelSource = LocalModelSource(name: modelName, path: modelPath)
        let registrationSuccessful = ModelManager.modelManager().register(localModelSource)
        print(registrationSuccessful)
    }
    
    private func getInterpreter() {
        let options = ModelOptions(cloudModelName: modelName, localModelName: modelName)
        let interpreter = ModelInterpreter.modelInterpreter(options: options)
        
        do {
            let inputData = try getModelInputs()
            let ioOptions = try getioOptions()
            
            interpreter.run(inputs: inputData, options: ioOptions) { [weak self] (modelOutputs, error) in
                
                guard let `self` = self,
                    error == nil,
                    let outputs = modelOutputs else { return }
                
                if let output = try? outputs.output(index: 0) as? [[Float]],
                    let ratingOutput = output?.first {
                    
                    let productList = self.getProductList()
                    var productRatingMapping:[String:Float] = [:]
                    var index = 0
                    
                    while index < ratingOutput.count {
                        let productId = productList[index]
                        productRatingMapping[productId] = ratingOutput[index] * 10
                        print("ratingOutput:\(productRatingMapping[productId]!) Index: \(index)\n")
                        print("User Input: \(self.userInputData[0][index]): Index: \(index)\n")
                        index += 1
                    }
                    
                    let productRatingSortedList = productRatingMapping.sorted(by: {$0.value>$1.value}).prefix(10)
                    
                    print("Sorted List of Products")
                    print("User Input: \(self.userInputData[0].prefix(10))\n")
                    print("User Output:")
                    productRatingSortedList.forEach { print("\($0): \($1)") }
                    print("Done.")
                }
            }
        }catch let error {
            print(error)
        }
        
    }
}

extension ViewController {
    private func getModelInputs() throws -> ModelInputs  {
        let inputs = ModelInputs()
        
        do {
            let inputData:[[Float]] = getInputData()
            //            print("First 10 input data: \(inputData.first?.prefix(10))\n")
            try inputs.addInput(inputData)
            return inputs
        }catch let error {
            print("Failed to add input: \(error)")
            throw(error)
        }
    }
    
    private func getioOptions() throws -> ModelInputOutputOptions{
        let ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1,1000])
            try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1,1000])
            return ioOptions
        }catch let error {
            print("Failed to set input or output format with error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getInputData() -> [[Float]] {
        var inputData = [Float]()
        
        for _ in 0..<1000 {
            inputData.append(Float.random(in: pickRandomNumberPerCategory()).rounded())
        }
        self.userInputData = [inputData]
        return [inputData]
    }
    
    private func pickRandomNumberPerCategory() -> ClosedRange<Float> {
        var rangeArray = [ClosedRange<Float>]()
        
        let noVisitRange:ClosedRange<Float> = 0...0
        let visitRange:ClosedRange<Float> = 2...2
        let wishlistRange:ClosedRange<Float> = 5...5
        let cartRange:ClosedRange<Float> = 8...8
        let purchaseRange:ClosedRange<Float> = 10...10
        
        rangeArray.append(contentsOf: [noVisitRange,
                                       visitRange,
                                       wishlistRange,
                                       cartRange,
                                       purchaseRange])
        
        let index = Int.random(in: 0..<rangeArray.count)
        return rangeArray[index]
    }
    
    private func getProductList() -> [String] {
        guard let path = Bundle.main.path(forResource: productListFileName, ofType: ".json") else { return []}
        
        let products = try? String(contentsOfFile: path).components(separatedBy: "\n")
        
        return products ?? []
        
    }
}
