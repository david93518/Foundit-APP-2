package com.example.foundit.ui.navigation

import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import android.util.Base64
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.example.foundit.ui.screen.ai.AiMatchScreen
import com.example.foundit.ui.screen.auth.AuthViewModel
import com.example.foundit.ui.screen.auth.LoginScreen
import com.example.foundit.ui.screen.auth.OtpScreen
import com.example.foundit.ui.screen.chat.ChatListScreen
import com.example.foundit.ui.screen.chat.ChatRoomScreen
import com.example.foundit.ui.screen.chat.ChatViewModel
import com.example.foundit.ui.screen.home.HomeScreen
import com.example.foundit.ui.screen.home.HomeViewModel
import com.example.foundit.ui.screen.item.AddItemScreen
import com.example.foundit.ui.screen.item.ItemDetailScreen
import com.example.foundit.ui.screen.item.ItemViewModel
import com.example.foundit.ui.screen.map.MapScreen
import com.example.foundit.ui.screen.notification.NotificationScreen
import com.example.foundit.ui.screen.profile.EditProfileScreen
import com.example.foundit.ui.screen.profile.ProfileScreen
import com.example.foundit.ui.screen.profile.ProfileViewModel
import com.example.foundit.ui.screen.profile.SettingsScreen
import com.example.foundit.ui.screen.qr.QrScreen
import com.example.foundit.ui.screen.qr.QrViewModel
import com.example.foundit.ui.screen.search.SearchScreen
import com.example.foundit.ui.screen.splash.SplashScreen

@Composable
fun AppNavigation(
    navController: NavHostController,
    startDestination: String = Screen.Splash.route
) {
    val authViewModel: AuthViewModel = viewModel()
    val homeViewModel: HomeViewModel = viewModel()
    val itemViewModel: ItemViewModel = viewModel()
    val chatViewModel: ChatViewModel = viewModel()
    val qrViewModel: QrViewModel = viewModel()
    val profileViewModel: ProfileViewModel = viewModel()

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {

        // ── Splash ──
        composable(Screen.Splash.route) {
            SplashScreen(
                onNavigateToLogin = {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                },
                onNavigateToHome = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                },
                authViewModel = authViewModel
            )
        }

        // ── Login ──
        composable(Screen.Login.route) {
            LoginScreen(
                onNavigateToOtp = { phone ->
                    navController.navigate(Screen.Otp.createRoute(phone))
                },
                onNavigateToHome = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                },
                authViewModel = authViewModel
            )
        }

        // ── OTP 驗證 ──
        composable(
            route = Screen.Otp.route,
            arguments = listOf(navArgument("phone") { type = NavType.StringType })
        ) { backStackEntry ->
            val phone = backStackEntry.arguments?.getString("phone") ?: ""
            OtpScreen(
                phone = phone,
                onVerifySuccess = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                },
                onNavigateBack = { navController.popBackStack() },
                authViewModel = authViewModel
            )
        }

        // ── Home ──
        composable(Screen.Home.route) {
            HomeScreen(
                onNavigateToItemDetail = { itemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(itemId))
                },
                onNavigateToAddItem = { type ->
                    navController.navigate(Screen.AddItem.createRoute(type))
                },
                onNavigateToSearch = {
                    navController.navigate(Screen.Search.route)
                },
                onNavigateToMap = {
                    navController.navigate(Screen.Map.route)
                },
                onNavigateToNotification = {
                    navController.navigate(Screen.Notification.route)
                },
                navController = navController,
                homeViewModel = homeViewModel
            )
        }

        // ── Search ──
        composable(Screen.Search.route) {
            SearchScreen(
                onNavigateToItemDetail = { itemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(itemId))
                },
                onNavigateBack = { navController.popBackStack() },
                homeViewModel = homeViewModel
            )
        }

        // ── Map ──
        composable(Screen.Map.route) {
            MapScreen(
                onNavigateToItemDetail = { itemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(itemId))
                },
                onNavigateBack = { navController.popBackStack() },
                homeViewModel = homeViewModel
            )
        }

        // ── Add Item ──
        composable(
            route = Screen.AddItem.route,
            arguments = listOf(navArgument("type") { type = NavType.StringType })
        ) { backStackEntry ->
            val type = backStackEntry.arguments?.getString("type") ?: "lost"
            AddItemScreen(
                itemType = type,
                onSubmitSuccess = { itemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(itemId)) {
                        popUpTo(Screen.Home.route)
                    }
                },
                onNavigateBack = { navController.popBackStack() },
                itemViewModel = itemViewModel
            )
        }

        // ── Item Detail ──
        composable(
            route = Screen.ItemDetail.route,
            arguments = listOf(navArgument("itemId") { type = NavType.StringType })
        ) { backStackEntry ->
            val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
            ItemDetailScreen(
                itemId = itemId,
                onNavigateBack = { navController.popBackStack() },
                onNavigateToChat = { id, itemTitle, fromItem ->
                    navController.navigate(Screen.ChatRoom.createRoute(id, itemTitle, fromItem))
                },
                onNavigateToAiMatch = {
                    navController.navigate(Screen.AiMatch.createRoute(itemId))
                },
                onNavigateToEdit = {
                    navController.navigate(Screen.EditItem.createRoute(itemId))
                },
                itemViewModel = itemViewModel
            )
        }

        // ── Edit Item ──
        composable(
            route = Screen.EditItem.route,
            arguments = listOf(navArgument("itemId") { type = NavType.StringType })
        ) { backStackEntry ->
            val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
            AddItemScreen(
                itemType = "edit",
                editItemId = itemId,
                onSubmitSuccess = { _ -> navController.popBackStack() },
                onNavigateBack = { navController.popBackStack() },
                itemViewModel = itemViewModel
            )
        }

        // ── Chat List ──
        composable(Screen.ChatList.route) {
            ChatListScreen(
                onNavigateToChatRoom = { chatId, itemTitle ->
                    navController.navigate(Screen.ChatRoom.createRoute(chatId, itemTitle))
                },
                navController = navController,
                chatViewModel = chatViewModel
            )
        }

        // ── Chat Room ──
        composable(
            route = Screen.ChatRoom.route,
            arguments = listOf(
                navArgument("chatId") { type = NavType.StringType },
                navArgument("itemTitle") { type = NavType.StringType },
                navArgument("fromItem") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val chatId = backStackEntry.arguments?.getString("chatId") ?: ""
            val rawTitle = backStackEntry.arguments?.getString("itemTitle").orEmpty()
            val itemTitle = decodeChatNavTitle(rawTitle)
            val openAsItem = backStackEntry.arguments?.getString("fromItem") == "1"
            ChatRoomScreen(
                chatId = chatId,
                itemTitle = itemTitle,
                openAsItem = openAsItem,
                onNavigateBack = { navController.popBackStack() },
                chatViewModel = chatViewModel
            )
        }

        // ── QR ──
        composable(Screen.Qr.route) {
            QrScreen(
                onNavigateBack = { navController.popBackStack() },
                qrViewModel = qrViewModel
            )
        }

        // ── AI Match ──
        composable(
            route = Screen.AiMatch.route,
            arguments = listOf(navArgument("itemId") { type = NavType.StringType })
        ) { backStackEntry ->
            val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
            AiMatchScreen(
                itemId = itemId,
                onNavigateToItemDetail = { matchedItemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(matchedItemId))
                },
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // ── Profile ──
        composable(Screen.Profile.route) {
            ProfileScreen(
                onNavigateToSettings = { navController.navigate(Screen.Settings.route) },
                onNavigateToPoints = { navController.navigate(Screen.Points.route) },
                onNavigateToEditProfile = { navController.navigate(Screen.EditProfile.route) },
                onNavigateToItemDetail = { itemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(itemId))
                },
                onLogout = {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(0) { inclusive = true }
                    }
                },
                navController = navController,
                authViewModel = authViewModel
            )
        }

        // ── Edit Profile ──
        composable(Screen.EditProfile.route) {
            EditProfileScreen(
                onNavigateBack = { navController.popBackStack() },
                profileViewModel = profileViewModel
            )
        }

        // ── Notifications ──
        composable(Screen.Notification.route) {
            NotificationScreen(
                onNavigateBack = { navController.popBackStack() },
                onNavigateToItemDetail = { itemId ->
                    navController.navigate(Screen.ItemDetail.createRoute(itemId))
                }
            )
        }

        // ── Settings ──
        composable(Screen.Settings.route) {
            SettingsScreen(
                onNavigateBack = { navController.popBackStack() },
                onLogout = {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }

        // ── Points ──
        composable(Screen.Points.route) {
            PointsPlaceholderScreen(onNavigateBack = { navController.popBackStack() })
        }
    }
}

/** 與 [Screen.ChatRoom.createRoute] 的 Base64 編碼對應；解碼失敗時沿用原字串（相容舊路由） */
private fun decodeChatNavTitle(raw: String): String {
    if (raw.isBlank() || raw == "_") return ""
    return try {
        String(Base64.decode(raw, Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8)
    } catch (_: IllegalArgumentException) {
        raw
    }
}

@Composable
private fun PointsPlaceholderScreen(onNavigateBack: () -> Unit) {
    com.example.foundit.ui.component.PlaceholderScreen(
        title = "我的積分",
        onNavigateBack = onNavigateBack
    )
}
