import SwiftUI
import FirebaseAuth
import Combine


struct FeedbackView: View {
    enum Topic: String, CaseIterable, Identifiable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case feedback = "General Feedback"
        case other = "Other"
        var id: String { rawValue }
    }

    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var topic: Topic = .feedback
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Topic") {
                Picker("Topic", selection: $topic) {
                    ForEach(Topic.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Message") {
                TextEditor(text: $message)
                    .frame(minHeight: 150)
            }

            Section("Email (optional)") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .disabled(isSubmitting)
        .navigationTitle("Send Feedback")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") { submit() }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func submit() {
        let cleanedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedMessage.isEmpty else { return }
        errorMessage = nil
        isSubmitting = true
        FeedbackService.shared.submit(topic: topic.rawValue,
                                       message: cleanedMessage,
                                       email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                       userID: authVM.userSession?.uid)
        ToastCenter.shared.success("Feedback queued")
        dismiss()
    }
}
