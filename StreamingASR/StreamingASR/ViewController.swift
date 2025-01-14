//// Copyright (c) 2020 Facebook, Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.



import UIKit
import AVFoundation
import RosaKit
import Foundation


class ViewController: UIViewController {
    @IBOutlet weak var btnStart: UIButton!
    @IBOutlet weak var tvResult: UITextView!
    
    let audioEngine = AVAudioEngine()
    let serialQueue = DispatchQueue(label: "sasr.serial.queue")
    
    private let AUDIO_LEN_IN_SECOND = 6
    private let SAMPLE_RATE = 16000
    private let FFT_SIZE = 400
    private let HOP_LENGTH = 160
    private let MEL_NUMBERS = 80
    
    private let CHUNK_TO_READ = 5
    private let CHUNK_SIZE = 640
    private let SPECTROGRAM_X = 21
    private let SPECTROGRAM_Y = 80
    
    private let GAIN = pow(10, 2 * log10(32767.0))
    
    private let MEAN =  [
        16.462461471557617,
        17.020158767700195,
        17.27733039855957,
        17.273637771606445,
        17.78028678894043,
        18.112783432006836,
        18.322141647338867,
        18.3536319732666,
        18.220436096191406,
        17.93610191345215,
        17.650646209716797,
        17.505868911743164,
        17.450956344604492,
        17.420780181884766,
        17.36254119873047,
        17.24843978881836,
        17.073762893676758,
        16.893953323364258,
        16.62371826171875,
        16.279895782470703,
        16.046218872070312,
        15.789617538452148,
        15.458984375,
        15.335075378417969,
        15.103074073791504,
        14.993032455444336,
        14.818647384643555,
        14.713132858276367,
        14.576343536376953,
        14.482580184936523,
        14.431093215942383,
        14.392385482788086,
        14.357626914978027,
        14.335031509399414,
        14.344644546508789,
        14.341029167175293,
        14.338135719299316,
        14.311485290527344,
        14.266831398010254,
        14.205205917358398,
        14.159194946289062,
        14.07589054107666,
        14.02244758605957,
        13.954248428344727,
        13.897454261779785,
        13.856722831726074,
        13.80321216583252,
        13.75955867767334,
        13.718783378601074,
        13.67695426940918,
        13.626880645751953,
        13.554975509643555,
        13.465453147888184,
        13.372663497924805,
        13.269320487976074,
        13.184920310974121,
        13.094778060913086,
        12.998514175415039,
        12.891039848327637,
        12.765382766723633,
        12.638651847839355,
        12.50733470916748,
        12.345802307128906,
        12.195826530456543,
        12.019110679626465,
        11.842704772949219,
        11.680868148803711,
        11.518675804138184,
        11.37252426147461,
        11.252099990844727,
        11.12936019897461,
        11.029287338256836,
        10.927411079406738,
        10.825841903686523,
        10.717211723327637,
        10.499553680419922,
        9.722028732299805,
        8.256664276123047,
        7.897761344909668,
        7.252806663513184
    ]

    private let INVSTDDEV = [
        0.2532021571066031,
        0.2597563367511928,
        0.2579079373215276,
        0.2416085222005694,
        0.23003407153886749,
        0.21714598348479108,
        0.20868966256973892,
        0.20397882792073063,
        0.20346486748979434,
        0.20568288111895272,
        0.20795624145573485,
        0.20848980415063503,
        0.20735096423640872,
        0.2060772210458722,
        0.20577174595523076,
        0.20655349986725383,
        0.2080547906859301,
        0.21015748217276387,
        0.2127639989370032,
        0.2156462785763535,
        0.21848300746868443,
        0.22174608140608748,
        0.22541974458780933,
        0.22897465119671973,
        0.23207484606149037,
        0.2353556049061462,
        0.23820711835547867,
        0.24016651485087528,
        0.24200318561465783,
        0.2435905301766702,
        0.24527147180928432,
        0.2493368450351618,
        0.25120444993308483,
        0.2521961451825939,
        0.25358032484699955,
        0.25349767201088286,
        0.2534676894845623,
        0.25149125467665234,
        0.25001929593946776,
        0.25064096375066197,
        0.25194505955280033,
        0.25270402089338095,
        0.2535205901701615,
        0.25363568106276674,
        0.2535307075541985,
        0.25315144026701186,
        0.2523683857532224,
        0.25200854739575596,
        0.2516561583169735,
        0.25147053419035553,
        0.25187638352086095,
        0.25176343344798546,
        0.25256615785525305,
        0.25310796555079107,
        0.2535568871416053,
        0.2542411936874833,
        0.2544978632482573,
        0.2553210332506536,
        0.2567248511819892,
        0.2559665595456875,
        0.2564729970835735,
        0.2585267417223537,
        0.2573770145474615,
        0.2585495460828127,
        0.2593605768768532,
        0.25906572100606984,
        0.26026752519153573,
        0.2609952847918467,
        0.26222905157170767,
        0.26395874733435604,
        0.26404203898769246,
        0.26501581381370537,
        0.2666259054856709,
        0.2676190865432322,
        0.26813030555166134,
        0.26873271506658997,
        0.2624062353014993,
        0.2289515918968408,
        0.22755587298227964,
        0.24719513536827162
    ]
    
    private let module: InferenceModule = {
        if let filePath = Bundle.main.path(forResource:
            "streaming_asr", ofType: "ptl"),
            let module = InferenceModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Can't find the model file!")
        }
    }()
    

    @IBAction func startTapped(_ sender: Any) {
        if (self.btnStart.title(for: .normal)! == "Start") {
            self.btnStart.setTitle("Listening... Stop", for: .normal)
            
            do {
              try self.startRecording()
            } catch let error {
              print("There was a problem starting recording: \(error.localizedDescription)")
            }
        }
        else {
            self.btnStart.setTitle("Start", for: .normal)
            self.stopRecording()
        }
    }
}


extension ViewController {
    fileprivate func startRecording() throws {
        let inputNode = audioEngine.inputNode
        let inputNodeOutputFormat = inputNode.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(SAMPLE_RATE), channels: 1, interleaved: false)
        let formatConverter =  AVAudioConverter(from:inputNodeOutputFormat, to: targetFormat!)
        var pcmBufferToBeProcessed = [Float32]()
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNodeOutputFormat) { [unowned self] (buffer, _) in
                let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat!, frameCapacity: AVAudioFrameCount(targetFormat!.sampleRate) / 10)
                var error: NSError? = nil
            
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buffer
                }
                formatConverter!.convert(to: pcmBuffer!, error: &error, withInputFrom: inputBlock)

                let floatArray = Array(UnsafeBufferPointer(start: pcmBuffer!.floatChannelData![0], count:Int(pcmBuffer!.frameLength)))
                pcmBufferToBeProcessed += floatArray
            
                if pcmBufferToBeProcessed.count >= CHUNK_TO_READ * CHUNK_SIZE {
                    let samples = Array(pcmBufferToBeProcessed[0..<CHUNK_TO_READ * CHUNK_SIZE]) .map { Double($0)/1.0 }
                    pcmBufferToBeProcessed = Array(pcmBufferToBeProcessed[(CHUNK_TO_READ - 1) * CHUNK_SIZE..<pcmBufferToBeProcessed.count])
                    
                    serialQueue.async {
                        let melSpectrogram = samples.melspectrogram(nFFT: FFT_SIZE, hopLength: HOP_LENGTH, sampleRate: Int(SAMPLE_RATE), melsCount: MEL_NUMBERS)
                        var features: [[Float]] = Array(repeating: Array(repeating: 0.0, count: melSpectrogram.count), count: melSpectrogram[0].count)
                        for i in 0..<melSpectrogram.count {
                            for j in 0..<melSpectrogram[i].count {
                                features[j][i] = Float(melSpectrogram[i][j] * GAIN)
                                if (features[j][i] > exp(1.0)) {
                                    features[j][i] = log(features[j][i])
                                }
                                else {
                                    features[j][i] /= exp(1.0);
                                }
                            }
                        }
                        
                        let melSpecX = Int32(features.count - 1)
                        let melSpecY = Int32(features[0].count)
                        var modelInput = [Float32]()
                                            
                        for i in 0..<features.count-1 {
                            for j in 0..<features[i].count {
                                features[i][j] -= Float(MEAN[j])
                                features[i][j] *= Float(INVSTDDEV[j])
                                modelInput.append(features[i][j])
                            }
                        }
                                            
                        var result = self.module.recognize(&modelInput, melSpecX: melSpecX, melSpecY: melSpecY)
                        if result!.count > 0 {
                            result = result!.replacingOccurrences(of: "▁", with: "")
                            DispatchQueue.main.async {
                                self.tvResult.text = self.tvResult.text + " " + result!
                            }
                        }
                    }
                }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    
    fileprivate func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
