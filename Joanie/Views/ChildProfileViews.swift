import SwiftUI

struct AddChildView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSave: (Child) -> Void
    
    @State private var childName = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var selectedAvatar: UIImage?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Child Information")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        TextField("Child's Name", text: $childName)
                    }
                    
                    Toggle("Include Birth Date", isOn: $hasBirthDate)
                    
                    if hasBirthDate {
                        DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Profile Picture")) {
                    HStack {
                        if let avatar = selectedAvatar {
                            Image(uiImage: avatar)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.blue)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Button("Choose Photo") {
                                showingImagePicker = true
                            }
                            .foregroundColor(.blue)
                            
                            if selectedAvatar != nil {
                                Button("Remove Photo") {
                                    selectedAvatar = nil
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Section(footer: Text("You can always edit this information later from your profile.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChild()
                    }
                    .disabled(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                SingleImagePicker(selectedImage: $selectedAvatar, sourceType: .photoLibrary)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveChild() {
        let trimmedName = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name for your child"
            showingError = true
            return
        }
        
        let newChild = Child(
            userId: UUID(), // This should be the current user's ID
            name: trimmedName,
            birthDate: hasBirthDate ? birthDate : nil,
            avatarURL: nil // TODO: Upload avatar image and get URL
        )
        
        onSave(newChild)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditChildView: View {
    @Environment(\.presentationMode) var presentationMode
    let child: Child
    let onSave: (Child) -> Void
    
    @State private var childName: String
    @State private var birthDate: Date
    @State private var hasBirthDate: Bool
    @State private var selectedAvatar: UIImage?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(child: Child, onSave: @escaping (Child) -> Void) {
        self.child = child
        self.onSave = onSave
        self._childName = State(initialValue: child.name)
        self._birthDate = State(initialValue: child.birthDate ?? Date())
        self._hasBirthDate = State(initialValue: child.birthDate != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Child Information")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        TextField("Child's Name", text: $childName)
                    }
                    
                    Toggle("Include Birth Date", isOn: $hasBirthDate)
                    
                    if hasBirthDate {
                        DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Profile Picture")) {
                    HStack {
                        if let avatar = selectedAvatar {
                            Image(uiImage: avatar)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else if let avatarURL = child.avatarURL {
                            AsyncImage(url: URL(string: avatarURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .overlay(
                                        Text(child.initials)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(child.initials)
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Button("Choose Photo") {
                                showingImagePicker = true
                            }
                            .foregroundColor(.blue)
                            
                            if selectedAvatar != nil || child.avatarURL != nil {
                                Button("Remove Photo") {
                                    selectedAvatar = nil
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Section(footer: Text("Changes will be saved to your profile.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Child")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChild()
                    }
                    .disabled(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                SingleImagePicker(selectedImage: $selectedAvatar, sourceType: .photoLibrary)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveChild() {
        let trimmedName = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name for your child"
            showingError = true
            return
        }
        
        let updatedChild = child.withUpdatedName(trimmedName)
            .withUpdatedBirthDate(hasBirthDate ? birthDate : nil)
            // TODO: Handle avatar URL update
        
        onSave(updatedChild)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    let profile: UserProfile?
    let onSave: (UserProfile) -> Void
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(profile: UserProfile?, onSave: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        self._firstName = State(initialValue: profile?.firstName ?? "")
        self._lastName = State(initialValue: profile?.lastName ?? "")
        self._email = State(initialValue: profile?.email ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        TextField("First Name", text: $firstName)
                    }
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        TextField("Last Name", text: $lastName)
                    }
                }
                
                Section(header: Text("Account Information")) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        TextField("Email", text: $email)
                            .disabled(true) // Email is typically not editable
                    }
                }
                
                Section(footer: Text("Changes will be saved to your account.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveProfile() {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedFirstName.isEmpty && !trimmedLastName.isEmpty else {
            errorMessage = "Please enter both first and last name"
            showingError = true
            return
        }
        
        guard let currentProfile = profile else {
            errorMessage = "Profile not found"
            showingError = true
            return
        }
        
        let updatedProfile = UserProfile(
            id: currentProfile.id,
            email: currentProfile.email,
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            createdAt: currentProfile.createdAt,
            updatedAt: Date()
        )
        
        onSave(updatedProfile)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AddChildView { _ in }
}
