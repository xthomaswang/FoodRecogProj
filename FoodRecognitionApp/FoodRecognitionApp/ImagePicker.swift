//
//  ImagePicker.swift
//  FoodRecognitionApp
//
//  Created by Thomas Wang on 12/5/24.
//

import SwiftUI
import UIKit
import CoreML
import Vision
import CoreVideo


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isShown: Bool
    var sourceType: UIImagePickerController.SourceType
    @Binding var classificationLabel: String
    
    // MARK: - UIViewControllerRepresentable
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = self.sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        // Called when an image was chosen
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.isShown = false
            if let uiImage = info[.originalImage] as? UIImage {
                let normalizedImage = uiImage.normalizedOrientation()
                parent.image = normalizedImage
                // You can choose one of the following approaches:
                // 1) Use Vision (Recommended)
                parent.classifyWithVision(image: normalizedImage)
                
                // 2) Or direct Core ML prediction (if you must)
                // parent.detectDirect(image: normalizedImage)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isShown = false
        }
    }
    
    // MARK: - Vision-based Classification (Recommended)
    func classifyWithVision(image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    self.classificationLabel = "Invalid image."
                }
                return
            }
            
            // Load model as VNCoreMLModel
            guard let visionModel = try? VNCoreMLModel(for: FoodClassifier().model) else {
                DispatchQueue.main.async {
                    self.classificationLabel = "Failed to load model."
                }
                return
            }
            
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let results = request.results as? [VNClassificationObservation],
                   let topResult = results.first {
                    DispatchQueue.main.async {
                        let confidence = (topResult.confidence * 100).rounded()
                        self.classificationLabel = "Prediction: \(topResult.identifier)\nConfidence: \(confidence)%"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.classificationLabel = "No prediction found."
                    }
                }
            }
            
            // Perform the request
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.classificationLabel = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Direct Core ML Prediction (If Needed)
    // This approach is more manual and must match the model’s preprocessing exactly.
    func detectDirect(image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Normalize orientation
            let normalizedImage = image.normalizedOrientation()
            
            // Resize image to model's expected size (224x224 assumed)
            let targetSize = CGSize(width: 224, height: 224)
            guard let resizedImage = normalizedImage.resized(to: targetSize) else {
                DispatchQueue.main.async {
                    self.classificationLabel = "Failed to resize image."
                }
                return
            }
            
            // Convert to CVPixelBuffer
            guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
                DispatchQueue.main.async {
                    self.classificationLabel = "Failed to convert image to pixel buffer."
                }
                return
            }
            
            // Load the Core ML model directly
            let config = MLModelConfiguration()
            do {
                let model = try FoodClassifier(configuration: config)
                // Make a prediction using the correct input name
                let prediction = try model.prediction(input_4: pixelBuffer)
                
                let outputDict = prediction.Identity
                if let maxEntry = outputDict.max(by: { $0.value < $1.value }) {
                    let foodName = maxEntry.key
                    let confidence = (maxEntry.value * 100).rounded()
                    DispatchQueue.main.async {
                        self.classificationLabel = "Prediction: \(foodName)\nConfidence: \(confidence)%"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.classificationLabel = "Failed to process output dictionary."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.classificationLabel = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - UIImage Extensions
extension UIImage {
    // Normalize image orientation
    func normalizedOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
    
    // Resizes the image to the specified size
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let newImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        return newImage
    }

    // Convert image to CVPixelBuffer
    func toCVPixelBuffer() -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        return buffer
    }
}

// MARK: - MLMultiArray Extensions (If needed)
extension MLMultiArray {
    func toArray() -> [Float]? {
        let count = self.count
        var array = [Float](repeating: 0, count: count)
        let pointer = UnsafeMutablePointer(&array)
        memcpy(pointer, self.dataPointer, count * MemoryLayout<Float>.stride)
        return array
    }

    func toReadableString() -> String {
        guard let array = self.toArray() else { return "N/A" }
        return array.map { String($0) }.joined(separator: ", ")
    }
}
