//
// DeepFilterNet3_Streaming.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
class DeepFilterNet3_StreamingInput : MLFeatureProvider {

    /// spec_buf as 1 × 1 × 10 × 481 × 2 5-dimensional array of 16-bit floats
    var spec_buf: MLMultiArray

    /// feat_erb_buf as 1 × 1 × 10 × 32 4-dimensional array of 16-bit floats
    var feat_erb_buf: MLMultiArray

    /// feat_spec_buf as 1 × 1 × 10 × 96 × 2 5-dimensional array of 16-bit floats
    var feat_spec_buf: MLMultiArray

    /// h_enc_in as 1 × 1 × 256 3-dimensional array of 16-bit floats
    var h_enc_in: MLMultiArray

    /// h_erb_in as 1 × 2 × 256 3-dimensional array of 16-bit floats
    var h_erb_in: MLMultiArray

    /// h_df_in as 1 × 2 × 256 3-dimensional array of 16-bit floats
    var h_df_in: MLMultiArray

    var featureNames: Set<String> { ["spec_buf", "feat_erb_buf", "feat_spec_buf", "h_enc_in", "h_erb_in", "h_df_in"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "spec_buf" {
            return MLFeatureValue(multiArray: spec_buf)
        }
        if featureName == "feat_erb_buf" {
            return MLFeatureValue(multiArray: feat_erb_buf)
        }
        if featureName == "feat_spec_buf" {
            return MLFeatureValue(multiArray: feat_spec_buf)
        }
        if featureName == "h_enc_in" {
            return MLFeatureValue(multiArray: h_enc_in)
        }
        if featureName == "h_erb_in" {
            return MLFeatureValue(multiArray: h_erb_in)
        }
        if featureName == "h_df_in" {
            return MLFeatureValue(multiArray: h_df_in)
        }
        return nil
    }

    init(spec_buf: MLMultiArray, feat_erb_buf: MLMultiArray, feat_spec_buf: MLMultiArray, h_enc_in: MLMultiArray, h_erb_in: MLMultiArray, h_df_in: MLMultiArray) {
        self.spec_buf = spec_buf
        self.feat_erb_buf = feat_erb_buf
        self.feat_spec_buf = feat_spec_buf
        self.h_enc_in = h_enc_in
        self.h_erb_in = h_erb_in
        self.h_df_in = h_df_in
    }

    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    convenience init(spec_buf: MLShapedArray<Float16>, feat_erb_buf: MLShapedArray<Float16>, feat_spec_buf: MLShapedArray<Float16>, h_enc_in: MLShapedArray<Float16>, h_erb_in: MLShapedArray<Float16>, h_df_in: MLShapedArray<Float16>) {
        self.init(spec_buf: MLMultiArray(spec_buf), feat_erb_buf: MLMultiArray(feat_erb_buf), feat_spec_buf: MLMultiArray(feat_spec_buf), h_enc_in: MLMultiArray(h_enc_in), h_erb_in: MLMultiArray(h_erb_in), h_df_in: MLMultiArray(h_df_in))
    }

}


/// Model Prediction Output Type
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
class DeepFilterNet3_StreamingOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// enhanced_spec as 1 × 1 × 1 × 481 × 2 5-dimensional array of 16-bit floats
    var enhanced_spec: MLMultiArray {
        provider.featureValue(for: "enhanced_spec")!.multiArrayValue!
    }

    /// enhanced_spec as 1 × 1 × 1 × 481 × 2 5-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    var enhanced_specShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(enhanced_spec)
    }

    /// mask as 1 × 1 × 1 × 32 4-dimensional array of 16-bit floats
    var mask: MLMultiArray {
        provider.featureValue(for: "mask")!.multiArrayValue!
    }

    /// mask as 1 × 1 × 1 × 32 4-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    var maskShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(mask)
    }

    /// lsnr as 1 × 1 × 1 3-dimensional array of 16-bit floats
    var lsnr: MLMultiArray {
        provider.featureValue(for: "lsnr")!.multiArrayValue!
    }

    /// lsnr as 1 × 1 × 1 3-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    var lsnrShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(lsnr)
    }

    /// h_enc_out as 1 × 1 × 256 3-dimensional array of 16-bit floats
    var h_enc_out: MLMultiArray {
        provider.featureValue(for: "h_enc_out")!.multiArrayValue!
    }

    /// h_enc_out as 1 × 1 × 256 3-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    var h_enc_outShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(h_enc_out)
    }

    /// h_erb_out as 1 × 2 × 256 3-dimensional array of 16-bit floats
    var h_erb_out: MLMultiArray {
        provider.featureValue(for: "h_erb_out")!.multiArrayValue!
    }

    /// h_erb_out as 1 × 2 × 256 3-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    var h_erb_outShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(h_erb_out)
    }

    /// h_df_out as 1 × 2 × 256 3-dimensional array of 16-bit floats
    var h_df_out: MLMultiArray {
        provider.featureValue(for: "h_df_out")!.multiArrayValue!
    }

    /// h_df_out as 1 × 2 × 256 3-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    var h_df_outShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(h_df_out)
    }

    var featureNames: Set<String> {
        provider.featureNames
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        provider.featureValue(for: featureName)
    }

    init(enhanced_spec: MLMultiArray, mask: MLMultiArray, lsnr: MLMultiArray, h_enc_out: MLMultiArray, h_erb_out: MLMultiArray, h_df_out: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["enhanced_spec" : MLFeatureValue(multiArray: enhanced_spec), "mask" : MLFeatureValue(multiArray: mask), "lsnr" : MLFeatureValue(multiArray: lsnr), "h_enc_out" : MLFeatureValue(multiArray: h_enc_out), "h_erb_out" : MLFeatureValue(multiArray: h_erb_out), "h_df_out" : MLFeatureValue(multiArray: h_df_out)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
class DeepFilterNet3_Streaming {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "DeepFilterNet3_Streaming", withExtension:"mlmodelc")!
    }

    /**
        Construct DeepFilterNet3_Streaming instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of DeepFilterNet3_Streaming.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `DeepFilterNet3_Streaming.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct DeepFilterNet3_Streaming instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct DeepFilterNet3_Streaming instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<DeepFilterNet3_Streaming, Error>) -> Void) {
        load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct DeepFilterNet3_Streaming instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> DeepFilterNet3_Streaming {
        try await load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct DeepFilterNet3_Streaming instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<DeepFilterNet3_Streaming, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(DeepFilterNet3_Streaming(model: model)))
            }
        }
    }

    /**
        Construct DeepFilterNet3_Streaming instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> DeepFilterNet3_Streaming {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return DeepFilterNet3_Streaming(model: model)
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as DeepFilterNet3_StreamingInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as DeepFilterNet3_StreamingOutput
    */
    func prediction(input: DeepFilterNet3_StreamingInput) throws -> DeepFilterNet3_StreamingOutput {
        try prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as DeepFilterNet3_StreamingInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as DeepFilterNet3_StreamingOutput
    */
    func prediction(input: DeepFilterNet3_StreamingInput, options: MLPredictionOptions) throws -> DeepFilterNet3_StreamingOutput {
        let outFeatures = try model.prediction(from: input, options: options)
        return DeepFilterNet3_StreamingOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as DeepFilterNet3_StreamingInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as DeepFilterNet3_StreamingOutput
    */
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    func prediction(input: DeepFilterNet3_StreamingInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> DeepFilterNet3_StreamingOutput {
        let outFeatures = try await model.prediction(from: input, options: options)
        return DeepFilterNet3_StreamingOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - spec_buf: 1 × 1 × 10 × 481 × 2 5-dimensional array of 16-bit floats
            - feat_erb_buf: 1 × 1 × 10 × 32 4-dimensional array of 16-bit floats
            - feat_spec_buf: 1 × 1 × 10 × 96 × 2 5-dimensional array of 16-bit floats
            - h_enc_in: 1 × 1 × 256 3-dimensional array of 16-bit floats
            - h_erb_in: 1 × 2 × 256 3-dimensional array of 16-bit floats
            - h_df_in: 1 × 2 × 256 3-dimensional array of 16-bit floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as DeepFilterNet3_StreamingOutput
    */
    func prediction(spec_buf: MLMultiArray, feat_erb_buf: MLMultiArray, feat_spec_buf: MLMultiArray, h_enc_in: MLMultiArray, h_erb_in: MLMultiArray, h_df_in: MLMultiArray) throws -> DeepFilterNet3_StreamingOutput {
        let input_ = DeepFilterNet3_StreamingInput(spec_buf: spec_buf, feat_erb_buf: feat_erb_buf, feat_spec_buf: feat_spec_buf, h_enc_in: h_enc_in, h_erb_in: h_erb_in, h_df_in: h_df_in)
        return try prediction(input: input_)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - spec_buf: 1 × 1 × 10 × 481 × 2 5-dimensional array of 16-bit floats
            - feat_erb_buf: 1 × 1 × 10 × 32 4-dimensional array of 16-bit floats
            - feat_spec_buf: 1 × 1 × 10 × 96 × 2 5-dimensional array of 16-bit floats
            - h_enc_in: 1 × 1 × 256 3-dimensional array of 16-bit floats
            - h_erb_in: 1 × 2 × 256 3-dimensional array of 16-bit floats
            - h_df_in: 1 × 2 × 256 3-dimensional array of 16-bit floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as DeepFilterNet3_StreamingOutput
    */

    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #else
    @available(macOS 15.0, *)
    #endif
    func prediction(spec_buf: MLShapedArray<Float16>, feat_erb_buf: MLShapedArray<Float16>, feat_spec_buf: MLShapedArray<Float16>, h_enc_in: MLShapedArray<Float16>, h_erb_in: MLShapedArray<Float16>, h_df_in: MLShapedArray<Float16>) throws -> DeepFilterNet3_StreamingOutput {
        let input_ = DeepFilterNet3_StreamingInput(spec_buf: spec_buf, feat_erb_buf: feat_erb_buf, feat_spec_buf: feat_spec_buf, h_enc_in: h_enc_in, h_erb_in: h_erb_in, h_df_in: h_df_in)
        return try prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - inputs: the inputs to the prediction as [DeepFilterNet3_StreamingInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [DeepFilterNet3_StreamingOutput]
    */
    func predictions(inputs: [DeepFilterNet3_StreamingInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [DeepFilterNet3_StreamingOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [DeepFilterNet3_StreamingOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  DeepFilterNet3_StreamingOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
