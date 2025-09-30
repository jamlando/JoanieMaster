

# **Product Requirements Document (PRD) for Joanie iOS App**

## **1\. Document Information**

* **Product Name**: Joanie  
* **Version**: 1.0  
* **Date**: September 30, 2025  
* **Author**: Grok (Technology Specialist)  
* **Stakeholders**: \[Your Name\] as Product Owner  
* **Overview**: This PRD outlines the requirements for developing Joanie, an iOS app designed to help parents digitally preserve and analyze their preschool and elementary-aged children's creative works (e.g., drawings, artwork, school assignments). The app emphasizes family engagement through AI-powered insights, storytelling, and progress tracking.

## **2\. Product Overview**

### **2.1 Problem Statement**

Parents of young children often accumulate physical piles of artwork, drawings, and schoolwork but struggle with storage, organization, and deriving educational value from them. They want to:

* Easily digitize and archive these items without clutter.  
* Receive actionable, age-appropriate tips to support their child's development in skills like writing, drawing, and fine motor control.  
* Turn creations into fun, personalized stories to foster creativity.  
* Visualize progress over time to celebrate milestones.

Joanie solves this by providing a seamless mobile experience for capture, storage, AI analysis, storytelling, and timeline visualization, tailored for busy parents.

### **2.2 Goals and Objectives**

* **Primary Goal**: Empower parents to preserve memories while actively supporting child development through intuitive AI features.  
* **Key Objectives**:  
  * Achieve 10,000 downloads in the first year post-launch.  
  * 70% user retention after 30 days via engaging features.  
  * Positive feedback on AI accuracy (e.g., 4+ star rating on App Store).  
* **Non-Goals**: Cross-platform support (Android/web) in v1.0; advanced printing/physical book creation; multi-child accounts beyond basic family sharing.

### **2.3 Assumptions and Dependencies**

* Users have iOS devices (iPhone 12+ for optimal camera/AI performance).  
* AI integrations (e.g., for tips and story generation) will use third-party services like OpenAI GPT or xAI API (to be selected in design phase).  
* Compliance with COPPA (Children's Online Privacy Protection Act) for child data handling.

## **3\. Target Audience**

* **Primary Users**: Parents (moms and dads) aged 25-45 with children aged 3-10 (preschool to early elementary).  
* **User Personas**:  
  * **Persona 1: Busy Working Mom (Sarah, 32\)**: Full-time professional, values quick uploads and bite-sized tips during commutes. Seeks progress timelines for teacher updates.  
  * **Persona 2: Involved Dad (Mike, 38\)**: Enjoys creative activities; excited about AI stories to read at bedtime. Wants family sharing without complexity.  
* **User Needs**:  
  * Simple, one-tap photo capture and upload.  
  * Privacy-focused storage (no public sharing by default).  
  * Educational content aligned with developmental stages (e.g., ages 3-5: coloring basics; 6-8: narrative writing).

## **4\. Key Features and Requirements**

Features are prioritized as Must-Have (M), Should-Have (S), or Could-Have (C) for MVP (Minimum Viable Product).

### **4.1 Core Features**

| Feature | Description | Priority | Acceptance Criteria |
| ----- | ----- | ----- | ----- |
| **Photo Capture & Upload** | Users take or select photos of child's work (drawings, art, school assignments) and upload to a secure account. Auto-tagging with date, child name, category (e.g., drawing/writing). | M | \- Camera integration for in-app capture. \- Supports multiple photos per entry. \- Upload success notification; offline queuing. |
| **Secure Storage & Account Management** | Cloud storage per child profile; family accounts for multi-parent access. Basic auth (email/password or Apple Sign-In). | M | \- Data encrypted at rest/transit. \- Unlimited storage for MVP (tiered in future). \- Delete/edit entries. |
| **AI-Powered Tips/Hints** | Analyze uploaded images (e.g., via computer vision) to provide personalized tips on skill improvement (writing legibility, coloring in lines, creative expression). Tips categorized by age/skill level. | M | \- 3-5 tips per analysis, with links to resources (e.g., videos). \- Opt-in for analysis to address privacy. \- Accuracy \>80% via AI model testing. |
| **AI Story Generation** | Select 2-5 artworks; AI generates a cohesive story using them as illustrations, with child/parent as characters. Export as PDF/eBook or shareable link. | S | \- Customizable prompts (e.g., "adventure" theme). \- Voiceover option for bedtime reading. \- Generation time \<30 seconds. |
| **Progress Timeline** | Chronological gallery/timeline view showing child's works over time. Overlay metrics (e.g., "Improved line control by 40%") based on AI analysis trends. | M | \- Filter by date/category/skill. \- Visual charts (e.g., skill progress bars). \- Export timeline as video/slideshow. |

4.2 Supporting Features

| Feature | Description | Priority | Acceptance Criteria |
| ----- | ----- | ----- | ----- |
| **Child Profiles** | Create profiles for multiple children; assign uploads to profiles. | M | \- Age-based customization for tips/stories. |
| **Family Sharing** | Invite co-parent/guardian to view/edit shared child's profile. | S | \- Role-based access (view-only vs. edit). |
| **Search & Organization** | Search by tags, dates, or keywords; album creation. | S | \- AI-suggested tags (e.g., "space theme"). |
| **Notifications** | Reminders to upload weekly; new tip alerts. | C | \- Push notifications via APNs. |
| **Analytics Dashboard** | Parent view of overall progress (e.g., skill heatmaps). | C | \- Weekly summaries emailed. |

### **4.3 Non-Functional Requirements**

* **Performance**: App loads in \<2 seconds; uploads \<10 seconds on 4G.  
* **Accessibility**: WCAG 2.1 AA compliant (e.g., VoiceOver support for tips).  
* **Security**: GDPR/COPPA compliant; no child data used for training AI without consent.  
* **Scalability**: Handle 1,000 concurrent users initially.

## **5\. User Stories and Flows**

### 5.1 High-Level User Flows (Detailed Expansion)

### This section provides a deeper dive into the high-level user flows outlined in the PRD. For each flow, I've expanded with step-by-step breakdowns, including sub-steps, UI/UX considerations, edge cases, error handling, and integration points with the technical stack (e.g., SwiftUI views, Supabase backend calls). These flows assume a tab-based navigation structure in the app (e.g., Home, Gallery, Timeline, Profile tabs) built with SwiftUI for responsive, gesture-friendly interactions. Flows are designed to be intuitive for non-tech-savvy parents, with minimal friction and progressive disclosure of features.

### To visualize these flows, I've described them in a structured format. If you'd like me to generate flowcharts (e.g., via Mermaid syntax or a simple diagram export), confirm, and I can proceed with that.

#### 1\. Onboarding Flow

### Purpose: Guide new users through account setup and initial child profile creation to ensure quick value realization. This flow emphasizes simplicity to reduce drop-off rates (target: \<10% abandonment).

### Detailed Steps:

1. ### App Launch and Initial Screen:

   * ### User opens the app (first time detected via UserDefaults in Swift).

   * ### Display a welcome screen with SwiftUI animation (e.g., fading family illustration) and tagline: "Preserve, Analyze, and Celebrate Your Child's Creativity."

   * ### Buttons: "Sign Up" (email/password via Supabase Auth) or "Sign In with Apple" for seamless iOS integration.

   * ### UX Consideration: Include a "Guest Mode" option for trial (limited to 5 uploads, no saving) to hook users without commitment.

   * ### Edge Case: If network offline, show cached welcome and prompt to retry auth later.

2. ### Account Creation:

   * ### Collect minimal info: Email, password (validated for strength), optional full name.

   * ### Backend: Supabase inserts user row; generates JWT for session.

   * ### Error Handling: Duplicate email → "Account exists, sign in?"; Invalid input → Inline red highlights with tips (e.g., "Password must be 8+ characters").

   * ### UX: Progress indicator (SwiftUI ProgressView) during auth.

3. ### Create Child Profile:

   * ### Post-auth, modal sheet: "Add Your First Child" with fields – Name (text), Age (picker: 3-10 years), Optional Photo (camera/gallery access via UIImagePickerController).

   * ### Auto-suggest age-based categories (e.g., for 4-year-old: "Focus on fine motor skills").

   * ### Backend: Supabase upsert to 'children' table, linked to user\_id; store photo in Supabase Storage.

   * ### Edge Case: Multiple children? Allow "Add Another" loop after first.

   * ### UX: Fun elements like emoji selectors for child avatar if no photo.

4. ### Tutorial on Capture:

   * ### Interactive carousel (SwiftUI TabView): 3-4 slides showing "Snap a photo → Get tips → Build stories."

   * ### Include a demo upload: Prompt to take a test photo (discarded after).

   * ### End with "Get Started" button routing to Home tab.

   * ### Analytics: Track completion rate via Firebase (if integrated).

   * ### Edge Case: Skip option; if skipped, show subtle tooltips on first use.

### Flow Metrics: Expected duration: 2-3 minutes. Success: User reaches Home with at least one child profile.

#### 2\. Daily Use Flow (Capture & Upload)

### Purpose: Enable effortless digitization of child's work as a habitual action, integrated with AI tips for immediate value. This is the core loop to drive daily engagement.

### Detailed Steps:

1. ### App Open and Home Screen:

   * ### Default to Home tab: Dashboard with "Quick Capture" floating action button (FAB) and recent uploads grid.

   * ### If no uploads yet, show empty state: "Start by capturing your child's latest masterpiece\!" with illustration.

   * ### UX: Pull-to-refresh for syncing latest from Supabase.

2. ### Initiate Capture:

   * ### Tap FAB → Open camera view (AVCaptureSession in SwiftUI wrapper).

   * ### Options: Live photo mode for drawings/art; Document scanner mode (VNDocumentCameraViewController) for schoolwork to auto-crop/enhance.

   * ### Sub-Step: Select child profile if multiple (dropdown or segmented control).

   * ### Edge Case: Permission denied → System prompt; Fallback to gallery import.

3. ### Snap Photo and Preview:

   * ### Capture image → Preview screen with edits (crop, rotate via SwiftUI gestures).

   * ### Auto-tag: Use Apple's Vision framework for basic detection (e.g., "drawing" if lines detected) \+ date from metadata.

   * ### UX: "Add Notes" field for parent descriptions (e.g., "First attempt at writing name").

4. ### Auto-Upload & Tag:

   * ### On confirm, upload to Supabase Storage; Insert metadata to 'uploads' table (child\_id, tags, timestamp).

   * ### Offline: Queue in Core Data, sync on reconnect.

   * ### Progress: SwiftUI overlay with spinner; Success toast: "Uploaded\! Analyzing..."

   * ### Error Handling: Upload fail → Retry button; Storage limit (future) → Upsell premium.

5. ### View Tips Popup:

   * ### Post-upload, trigger AI analysis (background task via URLSession to OpenAI/xAI API: Send image URL, get tips JSON).

   * ### Display modal: 3-5 tips (e.g., "Encourage using crayons for better grip – try this activity: \[link\]").

   * ### UX: Swipeable cards; "Save Tip" to favorites; Opt-out toggle in settings.

   * ### Edge Case: AI fail (e.g., poor image quality) → "Retry analysis?" or generic tips.

### Flow Metrics: Expected duration: \<1 minute per upload. Retention driver: Tips viewed \>50% of uploads.

#### 3\. Story Creation Flow

### Purpose: Transform archived works into engaging narratives to boost family bonding and creativity. This feature differentiates Joanie by leveraging AI for personalization.

### Detailed Steps:

1. ### Navigate to Gallery:

   * ### Gallery tab: Grid view of uploads, filtered by child/date/category (SwiftUI LazyVGrid for performance).

   * ### Search bar for quick find (integrated with Supabase full-text search).

2. ### Select Images:

   * ### Multi-select mode (long-press to enter): Choose 2-5 images.

   * ### UX: Counter badge (e.g., "3 selected"); Preview thumbnails in selection bar.

   * ### Edge Case: \<2 selected → Disable "Create Story" button with tooltip.

3. ### Initiate Story Creation:

   * ### Tap "Create Story" → Prompt sheet: Theme picker (e.g., "Adventure", "Fantasy"), Character names (default: child's name), Length (short/medium).

   * ### Backend: Send selected image URLs \+ prompt to AI API (e.g., "Generate a story using these drawings as illustrations: \[descriptions\]").

4. ### AI Generates Story:

   * ### Progress: Loading animation (e.g., "Weaving magic...").

   * ### Output: Story text with embedded images (SwiftUI Text \+ AsyncImage).

   * ### Sub-Step: Auto-generate image descriptions if needed via Vision API.

   * ### Error Handling: API timeout → "Try again?"; Inappropriate content (rare) → Filter via moderation.

5. ### Preview & Save/Share:

   * ### Full-screen preview: Scrollable eBook layout; Optional voiceover (AVSpeechSynthesizer).

   * ### Buttons: Edit (tweak prompt & regenerate), Save (to 'stories' table in Supabase), Share (PDF export via UIActivityViewController or link).

   * ### UX: "Read Aloud" button for accessibility.

   * ### Edge Case: Large story → Paginate; Share fail → Copy link fallback.

### Flow Metrics: Expected duration: 2-5 minutes. Adoption target: 30% of users create 1+ story/month.

#### 4\. Progress Review Flow

### Purpose: Provide motivational insights into child's development, turning data into visual stories for parents and educators.

### Detailed Steps:

1. ### Navigate to Timeline Tab:

   * ### Timeline view: Infinite scroll (SwiftUI List) of entries by date, with thumbnails and skill badges (e.g., "Writing: Improving").

   * ### Filters: Date range, Skill type (dropdown), Child selector.

2. ### Scroll Chronologically:

   * ### Load data lazily from Supabase (query 'uploads' ordered by timestamp).

   * ### Visuals: Timeline markers (e.g., vertical line with bubbles); Group by month/year.

   * ### UX: Pinch-to-zoom for density; Infinite scroll with pagination.

3. ### Tap for Detailed Analysis:

   * ### On tap: Detail view with full image, original notes, and AI metrics (e.g., "Coloring accuracy: 75% → Up from 60% last month").

   * ### Sub-Step: Trend chart (SwiftUI Charts framework: Line graph of skill scores over time).

   * ### Backend: Aggregate analysis (query historical data, compute deltas via Supabase Edge Function).

   * ### Edge Case: Sparse data → "Add more uploads for better insights\!" prompt.

4. ### Export/Share Options:

   * ### From detail or timeline: "Export Progress" → Generate video/slideshow (combine images with AVFoundation) or PDF report.

   * ### Share via email/SMS for teachers/grandparents.

### Flow Metrics: Expected duration: 3-5 minutes per session. Engagement: Average 2 views/week per user.

### These expanded flows align with the MVP priorities, focusing on core value while allowing for iterative improvements (e.g., A/B testing tip popups). If you'd like to add sequence diagrams, integrate specific SwiftUI code examples, or research UX best practices from similar apps, let me know\!

### **5.2 Sample User Stories**

* As a parent, I want to quickly snap a photo of my child's drawing so I can archive it without leaving the app.  
* As a mom, I want AI tips on how to help my 4-year-old color better, based on their latest artwork, so I can practice at home.  
* As a dad, I want to generate a bedtime story from my child's recent drawings, so we can read it together.  
* As a parent, I want a visual timeline of my child's artwork progress, so I can see improvements and share with family.

## **6\. Technical Stack and Architecture**

### **6.1 Frontend**

* **Language/Framework**: Swift with SwiftUI for declarative UI (responsive, modern iOS design).  
* **Development Tools**: Xcode for IDE/building; TestFlight for beta testing and distribution.

### **6.2 Backend**

* **Database/Storage**: Supabase (PostgreSQL for relational data like user profiles/timelines; Storage for images with auto-scaling).  
* **Authentication**: Supabase Auth (integrates with Apple Sign-In).  
* **AI Integrations**:  
  * Image Analysis/Tips: Use Vision framework (Apple) for basic detection \+ OpenAI Vision API for advanced insights (e.g., handwriting recognition).  
  * Story Generation: OpenAI GPT-4o or xAI Grok API for text generation, prompted with image descriptions.  
* **Version Control**: GitHub for repo management, CI/CD with GitHub Actions.

### **6.3 Architecture Overview**

* **MVVM Pattern**: Models (data from Supabase), Views (SwiftUI), ViewModels (business logic/AI calls).  
* **Offline Support**: Core Data for local caching; sync on reconnect.  
* **API Endpoints** (via Supabase Edge Functions): Upload image → Analyze → Store metadata.

### **6.4 Testing Strategy**

* Unit Tests: XCTest for SwiftUI views and AI prompt logic.  
* UI Tests: XCUITest for flows like upload/timeline.  
* Beta: TestFlight groups for 50+ parents; gather feedback on AI accuracy.

## **7\. Development Timeline (High-Level)**

Assuming a solo/small team (1-2 developers), 3-6 month MVP timeline:

| Phase | Duration | Key Milestones | Deliverables |
| ----- | ----- | ----- | ----- |
| **Research & Design** | Weeks 1-4 | Wireframes, user testing prototypes. | Figma designs; finalized features. |
| **Core Development** | Weeks 5-12 | Implement capture/upload, storage, timeline. | Working MVP without AI. |
| **AI Integration** | Weeks 13-16 | Add tips/story features; API testing. | Full feature set; internal alpha. |
| **Testing & Polish** | Weeks 17-20 | Bug fixes, accessibility; TestFlight beta. | App Store submission ready. |
| **Launch** | Week 21 | App Store review; marketing. | Live app; analytics setup. |

* **Total Estimated Effort**: 800-1,200 hours.  
* **Risks**: AI accuracy delays (mitigate with prompt engineering); App Store review for child data (pre-audit).

## **8\. Competitor Analysis**

Based on market research, Joanie enters a niche but growing space for digital art preservation. No single app fully combines storage, AI tips, story generation, and progress tracking—offering differentiation opportunities.

| Competitor | Key Features | Strengths | Weaknesses | Differentiation for Joanie |
| ----- | ----- | ----- | ----- | ----- |
| **Artkive** | Chronological storage, sharing, print books/frames from scanned art. | Established (10+ years), physical products. | No AI analysis/stories; paid for premium ($5.99/mo). | Joanie adds free AI tips/stories; focuses on digital progress insights. |
| **Keepy** | Organize artwork/schoolwork/mementos; private albums, voice notes. | Secure, family collaboration. | Basic organization; no AI or timelines. | Joanie's AI elevates from storage to educational tool. |
| **Twinkle Art** | Scan/organize/store artwork (iOS-only). | Simple scanning tech. | Newer, limited features. | Joanie expands with AI-driven engagement. |
| **ArtShow** | Capture/enhance/store/display art. | Enhancement tools for pros. | Less kid-focused; no stories/AI tips. | Joanie targets parents with child-specific AI. |
| **Artsonia** | Online gallery uploads, cropping. | School integration. | Public-facing; less private. | Joanie prioritizes family privacy and personalization. |
| **crAion / Drawings Alive** | AI to animate/analyze drawings for emotional insights. | Fun AI visualization. | Standalone; no storage/timeline. | Joanie integrates analysis into a full archive ecosystem. |
| **AI Kid Draw Analysis** | Interpret drawings for emotional/developmental meaning (Android). | Psychological tips. | Platform-limited; no stories/storage. | Joanie's iOS focus \+ comprehensive features. |

**Market Gap**: Competitors excel in storage (Artkive/Keepy) or isolated AI (crAion), but lack Joanie's holistic blend of preservation, education, and creativity. Opportunity: Position as "AI-powered memory keeper for growing artists."

## **9\. Success Metrics and Next Steps**

* **KPIs**: DAU/MAU, feature adoption (e.g., % using AI stories), NPS score \>7.  
* **Analytics**: Integrate Firebase or Supabase Analytics.  
* **Next Steps**:  
  1. Validate with 10 parent interviews (1 week).  
  2. Create wireframes in Figma.  
  3. Set up GitHub repo and Supabase project.  
  4. Prototype core upload feature in Xcode.

