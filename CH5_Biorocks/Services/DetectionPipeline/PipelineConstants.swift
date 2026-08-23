import Foundation

nonisolated enum PipelineConstants {
    static let sampleRate: Double = 16_000
    static let classifierWindowSeconds: Double = 1.92
    static let gateWindowSeconds: Double = 2.0
    static let hopSeconds: Double = 0.25
    static let nSigma: Double = 4.0
    static let refractorySeconds: Double = 1.0
    static let blastThreshold: Double = 0.7653
    static let debounceK = 1
    static let debounceN = 3
    static let debounceSpanSeconds: Double = 5.0
    static let matchWindowSeconds: Double = 2.0
    static let healthPeriodSeconds: Double = 60.0
    static let listenPort: UInt16 = 17_455
    static let protocolName = "reefguard-hydro-v1"

    static let featureNames = [
        "spectral_centroid", "spectral_bandwidth", "spectral_rolloff", "spectral_flatness",
        "zcr", "rms", "crest_factor", "low_freq_energy_ratio", "high_freq_energy_ratio",
        "impulse_duration_ms",
        "mfcc_1", "mfcc_2", "mfcc_3", "mfcc_4", "mfcc_5", "mfcc_6", "mfcc_7",
        "mfcc_8", "mfcc_9", "mfcc_10", "mfcc_11", "mfcc_12", "mfcc_13"
    ]

    static let bandpassSOS: [[Double]] = [
        [0.000048873287547016, 0.000097746575094032, 0.000048873287547016, 1, -1.7276704423958475, 0.7509696392756684],
        [1, 2, 1, 1, -1.850417009158114, 0.8851714928160607],
        [1, -2, 1, 1, -1.9589545149415866, 0.9595015408201356],
        [1, -2, 1, 1, -1.986903575524361, 0.9873029892378817]
    ]

    static let lowpass2kSOS: [[Double]] = [
        [0.010209480791203138, 0.020418961582406275, 0.010209480791203138, 1, -0.85539793277517, 0.2097153577565546],
        [1, 2, 1, 1, -1.1130298541633479, 0.5740619150839545]
    ]

    static let highpass2to8kSOS: [[Double]] = [
        [0.3466262, -0.6932524, 0.3466262, 1, -0.85528881, 0.20967982],
        [1, -2, 1, 1, -1.11304003, 0.57410281],
        [1, 2, 1, 1, 1.99927441, 0.99927457],
        [1, 2, 1, 1, 1.99969937, 0.99969952]
    ]
}
