import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject private var router: MoodAppRouter
    @EnvironmentObject private var userDataProvider: UserDataProvider
    
    @State private var posts: [MoodPost] = []
    @State private var isInitialLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePosts: Bool = true
    @State private var currentSkip: Int = 0
    @State private var errorMessage: String?
    
    @State private var selectedPostForDetail: FeedItem?
    @State private var showDetailViewAnimated: Bool = false
    
    @State private var showSortOptions: Bool = false
    @State private var lastRefreshedDate = Date()
    
    private let pageSize = 20
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ZStack {
                    VStack(spacing: 0) {
                        headerSection
                        
                        if isInitialLoading && posts.isEmpty {
                            initialLoadingView
                        } else {
                            feedContentView(geometry: geometry, scrollProxy: scrollProxy)
                        }
                    }
                    .blur(radius: showDetailViewAnimated ? 15 : 0)
                    .disabled(showDetailViewAnimated)
                    
                    if showDetailViewAnimated {
                        detailViewOverlay(geometry: geometry)
                    }
                }
                .background(Color.black.edgesIgnoringSafeArea(.all))
                .onAppear {
                    if posts.isEmpty {
                        loadInitialPosts()
                    }
                    lastRefreshedDate = Date()
                }
                .onReceive(router.homeTabTappedAgain) { _ in
                    handleRefresh(scrollProxy: scrollProxy)
                }
                .onReceive(router.homeFeedNeedsRefresh) {
                    print("HomeFeedView: Refresh signal received.")
                    handleRefresh(scrollProxy: scrollProxy)
                }
                .onReceive(router.commentCountUpdated) { update in
                    print("HomeFeedView: Comment count update received for post \(update.postId). New count: \(update.newCount)")
                    if let index = posts.firstIndex(where: { $0.id == update.postId }) {
                        let oldCommentsData = posts[index].comments?.data ?? []
                        let newCommentsInfo = CommentsInfo(count: update.newCount, data: oldCommentsData)
                        
                        let originalPost = posts[index]
                        let updatedPost = MoodPost(
                            id: originalPost.id,
                            userId: originalPost.userId,
                            emotion: originalPost.emotion,
                            reason: originalPost.reason,
                            people: originalPost.people,
                            activities: originalPost.activities,
                            privacy: originalPost.privacy,
                            location: originalPost.location,
                            timestamp: originalPost.timestamp,
                            likes: originalPost.likes,
                            comments: newCommentsInfo,
                            isAnonymous: originalPost.isAnonymous,
                            createdAt: originalPost.createdAt,
                            updatedAt: originalPost.updatedAt
                        )
                        posts[index] = updatedPost
                    }
                }
                .onReceive(router.userDidBlock) { blockedUserId in
                    print("HomeFeedView: Block event received for user \(blockedUserId). Removing their posts from the feed.")
                    posts.removeAll { $0.userId == blockedUserId }
                }
            }
        }
    }
    
    // MARK: - Enhanced Header Section with Sort Options
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Morii")
                    .font(.custom("Georgia", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { router.navigateToMoodFlow() }) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 22))
                        .foregroundColor(.pink)
                }
            }
            
            HStack {
                Text("How's everyone feeling?")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                // Sort selector
                Menu {
                    ForEach(FeedSortMethod.allCases, id: \.self) { sortMethod in
                        Button(action: {
                            if router.selectedSortMethod != sortMethod {
                                router.selectedSortMethod = sortMethod
                                loadInitialPosts() // Reload with new sort
                            }
                        }) {
                            HStack {
                                Image(systemName: sortMethod.icon)
                                Text(sortMethod.displayName)
                                if router.selectedSortMethod == sortMethod {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: router.selectedSortMethod.icon)
                            .font(.system(size: 14))
                        Text(router.selectedSortMethod.displayName)
                            .font(.custom("Georgia", size: 14))
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading Views
    @ViewBuilder
    private var initialLoadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading \(router.selectedSortMethod.displayName.lowercased()) feed...")
                .foregroundColor(.white)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var loadMoreView: some View {
        if isLoadingMore {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("Loading more posts...")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        } else if !hasMorePosts {
            Text("You've reached the end!")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(.white.opacity(0.5))
                .padding()
        }
    }
    
    // MARK: - Feed Content
    @ViewBuilder
    private func feedContentView(geometry: GeometryProxy, scrollProxy: ScrollViewProxy) -> some View {
        if posts.isEmpty && !isInitialLoading {
            emptyStateContent(geometry: geometry)
        } else {
            ScrollView {
                Color.clear.frame(height: 0).id("top_of_feed")
                LazyVStack(spacing: 16) {
                    ForEach(posts) { moodPostData in
                        let feedItem = moodPostData.toFeedItem()
                        MoodPostCard(
                            post: feedItem,
                            lastRefreshed: lastRefreshedDate,
                            openDetailAction: {
                                presentDetailView(for: feedItem)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            presentDetailView(for: feedItem)
                        }
                        .onAppear {
                            if moodPostData.id == posts.last?.id {
                                loadMorePostsIfNeeded()
                            }
                        }
                    }
                    loadMoreView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, max(100, geometry.safeAreaInsets.bottom) + 70)
            }
            .refreshable {
                await refreshPosts()
                lastRefreshedDate = Date()
            }
        }
        
        if let error = errorMessage {
            VStack {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                Button("Retry") {
                    if posts.isEmpty {
                        loadInitialPosts()
                    } else {
                        loadMorePostsIfNeeded()
                    }
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private func emptyStateContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: router.selectedSortMethod.icon)
                .font(.system(size: 60))
                .foregroundColor(.pink.opacity(0.6))
            VStack(spacing: 8) {
                Text("No \(router.selectedSortMethod.displayName.lowercased()) posts yet!")
                    .font(.custom("Georgia", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("Check in with your mood to see posts from friends and the community.")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button(action: { router.navigateToMoodFlow() }) {
                Text("Make your first check-in")
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.pink.opacity(0.8)))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, geometry.size.height * 0.1)
    }
    
    // MARK: - Detail View Overlay
    @ViewBuilder
    private func detailViewOverlay(geometry: GeometryProxy) -> some View {
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)
            .transition(.opacity)
            .onTapGesture { dismissDetailView() }
        
        if let postToShow = selectedPostForDetail {
            MoodPostDetailView(
                post: postToShow,
                onDismiss: dismissDetailView
            )
            .environmentObject(userDataProvider)
            .environmentObject(router)
            .frame(
                width: geometry.size.width * 0.95,
                height: max(
                    geometry.size.height * 0.5,
                    min(geometry.size.height * 0.90, 700)
                )
            )
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1)
        }
    }
    
    // MARK: - Pagination Logic (Updated)
    private func fetchPosts(skip: Int, limit: Int) async -> Result<(posts: [MoodPost], pagination: PaginationMetadata?), MoodPostServiceError> {
        await withCheckedContinuation { continuation in
            MoodPostService.fetchMoodPosts(
                skip: skip,
                limit: limit,
                sort: router.selectedSortMethod // Use selected sort method
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    private func loadInitialPosts() {
        guard !isInitialLoading else { return }
        
        isInitialLoading = true
        errorMessage = nil
        currentSkip = 0
        hasMorePosts = true
        posts.removeAll()
        
        Task {
            let result = await fetchPosts(skip: 0, limit: pageSize)
            await MainActor.run {
                isInitialLoading = false
                switch result {
                    case .success(let (newPosts, paginationInfo)):
                        self.posts = newPosts
                        if let pagination = paginationInfo {
                            self.hasMorePosts = pagination.currentPage < pagination.totalPages
                        } else {
                            self.hasMorePosts = newPosts.count == pageSize
                        }
                        self.currentSkip = newPosts.count
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                }
                self.lastRefreshedDate = Date()
            }
        }
    }
    
    private func loadMorePostsIfNeeded() {
        guard !isLoadingMore && hasMorePosts && !isInitialLoading else { return }
        
        isLoadingMore = true
        errorMessage = nil
        
        Task {
            let result = await fetchPosts(skip: currentSkip, limit: pageSize)
            await MainActor.run {
                isLoadingMore = false
                switch result {
                    case .success(let (newPosts, paginationInfo)):
                        if newPosts.isEmpty {
                            self.hasMorePosts = false
                        } else {
                            let existingIDs = Set(self.posts.map { $0.id })
                            let uniqueNewPosts = newPosts.filter { !existingIDs.contains($0.id) }
                            self.posts.append(contentsOf: uniqueNewPosts)
                            
                            self.currentSkip = self.posts.count
                            
                            if let pagination = paginationInfo {
                                self.hasMorePosts = pagination.currentPage < pagination.totalPages
                            } else {
                                self.hasMorePosts = newPosts.count == pageSize
                            }
                        }
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleRefresh(scrollProxy: ScrollViewProxy) {
        Task {
            withAnimation {
                scrollProxy.scrollTo("top_of_feed", anchor: .top)
            }
            
            // Allow scroll to complete before fetching
            try? await Task.sleep(nanoseconds: 250_000_000)
            await refreshPosts()
            lastRefreshedDate = Date()
        }
    }
    private func refreshPosts() async {
        await MainActor.run {
            isInitialLoading = true
            errorMessage = nil
            currentSkip = 0
            hasMorePosts = true
        }
        
        let result = await fetchPosts(skip: 0, limit: pageSize)
        
        await MainActor.run {
            isInitialLoading = false
            switch result {
                case .success(let (newPosts, paginationInfo)):
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.posts = newPosts
                        self.currentSkip = newPosts.count
                        
                        if let pagination = paginationInfo {
                            self.hasMorePosts = pagination.currentPage < pagination.totalPages
                        } else {
                            self.hasMorePosts = newPosts.count == pageSize
                        }
                        self.errorMessage = nil
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
            }
        }
    }
    
    
    // MARK: - Detail View Management
    private func dismissDetailView() {
        let detailViewWasActive = showDetailViewAnimated
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showDetailViewAnimated = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedPostForDetail = nil
        }
        if detailViewWasActive {
            router.tabWithActiveDetailView = nil
        }
        lastRefreshedDate = Date()
    }
    
    private func presentDetailView(for feedItem: FeedItem) {
        selectedPostForDetail = feedItem
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showDetailViewAnimated = true
        }
        router.tabWithActiveDetailView = .home
    }
}
