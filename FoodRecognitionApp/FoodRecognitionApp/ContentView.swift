//
//  ContentView.swift
//  FoodRecognitionApp
//
//  Created by Thomas Wang on 12/5/24.
//
import SwiftUI
import CoreML
import Vision
import PhotosUI

struct ContentView: View {
    @State private var image: UIImage?
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var classificationLabel: String = "Select an image to classify"
    @State private var showSourceOptions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background: Show the selected image full-screen if available, else a gradient
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black, Color.gray]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                
                VStack {
                    // Classification label - larger, centered text with a semi-transparent background
                    Text(classificationLabel)
                        .font(.system(size: 30, weight: .bold)) // Larger text size
                        .foregroundColor(Color.white.opacity(0.8)) // Slightly transparent white text
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 30)
                        .padding(.horizontal, 40)
                        .background(Color.black.opacity(0.3)) // Semi-transparent background
                        .cornerRadius(20) // Rounded corners for a nicer shape
                        .padding(.top, 80) // Move it down from the very top, giving space above
                        .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Bottom overlay: large "capture" button
                    HStack {
                        Spacer()
                        Button(action: {
                            showSourceOptions = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        Spacer()
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Food Classifier")
            .actionSheet(isPresented: $showSourceOptions) {
                ActionSheet(
                    title: Text("Select Image Source"),
                    buttons: [
                        .default(Text("Camera"), action: {
                            self.sourceType = .camera
                            self.showImagePicker = true
                        }),
                        .default(Text("Photo Library"), action: {
                            self.sourceType = .photoLibrary
                            self.showImagePicker = true
                        }),
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    image: self.$image,
                    isShown: self.$showImagePicker,
                    sourceType: self.sourceType,
                    classificationLabel: self.$classificationLabel
                )
            }
        }
    }
}
