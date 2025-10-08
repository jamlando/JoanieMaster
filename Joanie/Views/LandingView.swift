import SwiftUI

struct LandingView: View {
    @State private var currentSlide = 0
    @State private var showingSignUp = false
    @State private var showingLogin = false
    
    private let slides = [
        LandingSlide(
            title: "Tired of throwing away your child's drawings?",
            description: "Preserve every masterpiece digitally",
            icon: "trash.slash.fill",
            color: .red
        ),
        LandingSlide(
            title: "Upload to Joanie and create stories to share with your child.",
            description: "Transform artwork into magical bedtime stories",
            icon: "book.fill",
            color: .purple
        ),
        LandingSlide(
            title: "Watch your child's creativity grow",
            description: "Track progress and celebrate milestones",
            icon: "chart.line.uptrend.xyaxis",
            color: .green
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Hero Section
                VStack(spacing: 20) {
                    Spacer()
                    
                    // App Icon/Logo with Branding
                    HStack(spacing: 12) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Joanie")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 10)
                    
                    // Hero Text
                    Text("Transform your child's drawings into evolving bedtime stories.")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.4)
                
                // Carousel Section
                VStack(spacing: 20) {
                    // Carousel
                    TabView(selection: $currentSlide) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            LandingSlideView(slide: slides[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 200)
                    
                    // Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentSlide ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 10)
                }
                .frame(height: geometry.size.height * 0.35)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Sign Up Button
                    Button(action: {
                        showingSignUp = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Sign Up")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Login Button
                    Button(action: {
                        showingLogin = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Login")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color.blue.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingSignUp) {
            RegisterView(authService: DependencyContainer.shared.authService)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(authService: DependencyContainer.shared.authService)
        }
        .onAppear {
            // Auto-rotate carousel every 5 seconds
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentSlide = (currentSlide + 1) % slides.count
                }
            }
        }
    }
}

struct LandingSlide {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct LandingSlideView: View {
    let slide: LandingSlide
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: slide.icon)
                .font(.system(size: 60))
                .foregroundColor(slide.color)
            
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(slide.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LandingView()
}
