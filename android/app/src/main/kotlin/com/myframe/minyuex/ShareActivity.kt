package com.myframe.minyuex

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorSpace
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.ContentLoadingProgressBar
import androidx.lifecycle.lifecycleScope
import com.google.android.material.bottomsheet.BottomSheetDialog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

class ShareActivity : AppCompatActivity() {

    private lateinit var bottomSheetDialog: BottomSheetDialog
    
    // UI elements inside BottomSheet
    private lateinit var titleTextView: TextView
    private lateinit var cancelTextView: TextView
    private lateinit var thumbnailsLayout: LinearLayout
    private lateinit var framesLayout: LinearLayout
    private lateinit var sendButton: Button
    private lateinit var progressLayout: LinearLayout
    private lateinit var progressText: TextView
    private lateinit var progressBar: ProgressBar

    // Data
    private val imageUris = mutableListOf<Uri>()
    private val processedFiles = mutableListOf<File>()
    private val pairedFrames = mutableListOf<FrameInfo>()
    private val selectedFrameIds = mutableSetOf<String>()
    
    private var authToken = ""
    private var authUserId = ""

    data class FrameInfo(
        val id: String,
        val name: String,
        val mac: String,
        val apiUrl: String,
        val pairingToken: String,
        val isOnline: Boolean
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Hide activity content since it's just hosting the BottomSheet dialog
        val dummyView = View(this)
        setContentView(dummyView)

        // Parse external share intent
        parseIntent()

        if (imageUris.isEmpty()) {
            Toast.makeText(this, "No image to share", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        // Load credentials and frames list from SharedPreferences
        loadDataFromSharedPrefs()

        // Create and show BottomSheetDialog
        showBottomSheet()
    }

    private fun parseIntent() {
        val action = intent.action
        val type = intent.type
        if (type != null && type.startsWith("image/")) {
            if (Intent.ACTION_SEND == action) {
                val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (stream != null) {
                    imageUris.add(stream)
                }
            } else if (Intent.ACTION_SEND_MULTIPLE == action) {
                val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (streams != null) {
                    imageUris.addAll(streams.filterNotNull())
                }
            }
        }
    }

    private fun loadDataFromSharedPrefs() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // SharedPreferences keys inside FlutterSharedPreferences have "flutter." prefix
        authToken = prefs.getString("flutter.settings_auth_token", "") ?: ""
        authUserId = prefs.getString("flutter.settings_auth_user_id", "") ?: ""

        val onlineIdsSet = mutableSetOf<String>()
        val onlineIdsJsonStr = prefs.getString("flutter.ShareExtensionOnlineDeviceIds", "[]") ?: "[]"
        try {
            val arr = JSONArray(onlineIdsJsonStr)
            for (i in 0 until arr.length()) {
                onlineIdsSet.add(arr.getString(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val framesJsonStr = prefs.getString("flutter.paired_frames_json_v1", "[]") ?: "[]"
        try {
            val jsonArray = JSONArray(framesJsonStr)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val id = obj.optString("deviceId", obj.optString("id", ""))
                val name = obj.optString("frameName", obj.optString("name", ""))
                
                // Fallbacks to compute stationMac/mac/apiUrl/pairingToken matching syncFrames:
                // 'mac': targetId (station MAC preferred over BLE id)
                val targetId = obj.optString("deviceId", "")
                val apiUrl = obj.optString("apiUrl", "http://47.76.164.162:3001")
                val rawPairingToken = if (obj.has("pairingToken") && !obj.isNull("pairingToken")) obj.optString("pairingToken", "").trim() else ""
                val pairingToken = if (rawPairingToken.isNotEmpty() && !rawPairingToken.equals("null", ignoreCase = true) && !rawPairingToken.equals("undefined", ignoreCase = true)) {
                    rawPairingToken
                } else {
                    "framepass2026"
                }
                val isOnline = onlineIdsSet.contains(id)
                
                if (id.isNotEmpty()) {
                    pairedFrames.add(
                        FrameInfo(
                            id = id,
                            name = if (name.isNotEmpty()) name else "Frame ${id.takeLast(4)}",
                            mac = targetId,
                            apiUrl = apiUrl,
                            pairingToken = pairingToken,
                            isOnline = isOnline
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Auto-select the first online frame if available
        val firstOnline = pairedFrames.firstOrNull { it.isOnline }
        if (firstOnline != null) {
            selectedFrameIds.add(firstOnline.id)
        }
    }

    private fun showBottomSheet() {
        bottomSheetDialog = BottomSheetDialog(this)
        
        // Create root layout programmatically to avoid layout XML dependency
        val context = this
        val dp = { value: Int -> (value * resources.displayMetrics.density).toInt() }
        
        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
            setBackgroundColor(Color.parseColor("#121212")) // Sleek Dark Mode background
            val drawable = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1E1E"))
                cornerRadii = floatArrayOf(dp(16).toFloat(), dp(16).toFloat(), dp(16).toFloat(), dp(16).toFloat(), 0f, 0f, 0f, 0f)
            }
            background = drawable
        }

        // Header Layout
        val headerLayout = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, 0, 0, dp(16))
            }
        }

        titleTextView = TextView(context).apply {
            text = "Send Photos"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setTypeface(null, android.graphics.Typeface.BOLD)
            val params = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
            }
            layoutParams = params
        }
        headerLayout.addView(titleTextView)

        cancelTextView = TextView(context).apply {
            text = "Cancel"
            setTextColor(Color.parseColor("#E53935")) // Red color accent
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setPadding(dp(8), dp(8), dp(8), dp(8))
            val params = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.END or Gravity.CENTER_VERTICAL
            }
            layoutParams = params
            setOnClickListener {
                bottomSheetDialog.dismiss()
            }
        }
        headerLayout.addView(cancelTextView)
        rootLayout.addView(headerLayout)

        // Horizontal Preview List
        val horizontalScrollView = HorizontalScrollView(context).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(90)).apply {
                setMargins(0, 0, 0, dp(20))
            }
            isHorizontalScrollBarEnabled = false
        }
        thumbnailsLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        horizontalScrollView.addView(thumbnailsLayout)
        rootLayout.addView(horizontalScrollView)

        // Frames Section Header
        val framesHeaderTv = TextView(context).apply {
            text = "SELECT FRAMES"
            setTextColor(Color.parseColor("#757575"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(null, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, 0, 0, dp(8))
            }
        }
        rootLayout.addView(framesHeaderTv)

        // Frames List Layout
        framesLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, 0, 0, dp(20))
            }
        }
        rootLayout.addView(framesLayout)

        // Inline Progress Bar & Status Text
        progressLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, 0, 0, dp(16))
            }
        }
        progressBar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(4))
            progressDrawable = GradientDrawable().apply {
                setColor(Color.parseColor("#E53935"))
                cornerRadius = dp(2).toFloat()
            }
        }
        progressText = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, dp(6), 0, 0)
            }
        }
        progressLayout.addView(progressBar)
        progressLayout.addView(progressText)
        rootLayout.addView(progressLayout)

        // Send Button
        sendButton = Button(context).apply {
            text = "Send"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(null, android.graphics.Typeface.BOLD)
            setBackgroundColor(Color.parseColor("#E53935"))
            val drawable = GradientDrawable().apply {
                setColor(Color.parseColor("#E53935"))
                cornerRadius = dp(8).toFloat()
            }
            background = drawable
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48))
            setOnClickListener {
                startUploadFlow()
            }
        }
        rootLayout.addView(sendButton)

        bottomSheetDialog.setContentView(rootLayout)
        bottomSheetDialog.setOnDismissListener {
            cleanupTempFiles()
            finish()
        }

        // Render contents asynchronously (thumbnails & frames list)
        lifecycleScope.launch {
            renderThumbnails()
            renderFramesList()
        }

        bottomSheetDialog.show()
    }

    private suspend fun renderThumbnails() = withContext(Dispatchers.IO) {
        val dp = { value: Int -> (value * resources.displayMetrics.density).toInt() }
        for (uri in imageUris) {
            // Process (transcode and downscale for thumbnail preview)
            val bitmap = try {
                val options = BitmapFactory.Options().apply {
                    inSampleSize = 4
                }
                contentResolver.openInputStream(uri)?.use {
                    BitmapFactory.decodeStream(it, null, options)
                }
            } catch (e: Exception) {
                null
            }

            if (bitmap != null) {
                withContext(Dispatchers.Main) {
                    val imageView = ImageView(this@ShareActivity).apply {
                        val lp = LinearLayout.LayoutParams(dp(80), dp(80)).apply {
                            setMargins(0, 0, dp(8), 0)
                        }
                        layoutParams = lp
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        setImageBitmap(bitmap)
                        val drawable = GradientDrawable().apply {
                            cornerRadius = dp(8).toFloat()
                        }
                        clipToOutline = true
                        background = drawable
                    }
                    thumbnailsLayout.addView(imageView)
                }
            }
        }
    }

    private fun renderFramesList() {
        val dp = { value: Int -> (value * resources.displayMetrics.density).toInt() }
        
        if (pairedFrames.isEmpty()) {
            val emptyTv = TextView(this).apply {
                text = "No paired frames found. Open MyFrame app to pair."
                setTextColor(Color.parseColor("#757575"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setPadding(0, dp(8), 0, dp(8))
            }
            framesLayout.addView(emptyTv)
            sendButton.isEnabled = false
            sendButton.alpha = 0.5f
            return
        }

        for (frame in pairedFrames) {
            val itemLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dp(12), 0, dp(12))
                isClickable = true
                isFocusable = true
                
                if (!frame.isOnline) {
                    alpha = 0.5f
                }
                
            setOnClickListener {
                if (selectedFrameIds.contains(frame.id)) {
                    selectedFrameIds.remove(frame.id)
                } else {
                    selectedFrameIds.add(frame.id)
                }
                updateFramesSelectionUI()
            }
        }

        val nameLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        val nameTv = TextView(this).apply {
            text = frame.name
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        }
        nameLayout.addView(nameTv)

        if (!frame.isOnline) {
            val offlineTv = TextView(this).apply {
                text = "Offline"
                setTextColor(Color.parseColor("#E53935"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            }
            nameLayout.addView(offlineTv)
        }

        itemLayout.addView(nameLayout)

        val checkboxIv = ImageView(this).apply {
            tag = frame.id
            layoutParams = LinearLayout.LayoutParams(dp(24), dp(24))
        }
        itemLayout.addView(checkboxIv)

        framesLayout.addView(itemLayout)
    }

    updateFramesSelectionUI()
}

private fun updateFramesSelectionUI() {
    val dp = { value: Int -> (value * resources.displayMetrics.density).toInt() }
    for (i in 0 until framesLayout.childCount) {
        val view = framesLayout.getChildAt(i) as? LinearLayout ?: continue
        val checkboxIv = view.getChildAt(1) as? ImageView ?: continue
        val frameId = checkboxIv.tag as? String ?: continue
        
        checkboxIv.visibility = View.VISIBLE
        if (selectedFrameIds.contains(frameId)) {
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E53935"))
                setSize(dp(20), dp(20))
            }
            checkboxIv.setImageDrawable(drawable)
        } else {
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setStroke(dp(2), Color.parseColor("#757575"))
                setSize(dp(20), dp(20))
            }
            checkboxIv.setImageDrawable(drawable)
        }
    }
    
    val canSend = selectedFrameIds.isNotEmpty()
    sendButton.isEnabled = canSend
    sendButton.alpha = if (canSend) 1.0f else 0.5f
}

    private fun startUploadFlow() {
        sendButton.isEnabled = false
        sendButton.visibility = View.GONE
        progressLayout.visibility = View.VISIBLE
        cancelTextView.visibility = View.GONE
        bottomSheetDialog.setCancelable(false)

        lifecycleScope.launch {
            try {
                // 1. Decode & Transcode images
                updateProgress("Processing photos...", 10)
                transcodeImages()

                // 2. Upload to selected frame(s)
                updateProgress("Uploading photos...", 30)
                val ok = uploadProcessedImages()
                if (ok) {
                    updateProgress("Success!", 100)
                    Toast.makeText(this@ShareActivity, "Photos sent successfully!", Toast.LENGTH_SHORT).show()
                    bottomSheetDialog.dismiss()
                } else {
                    showErrorState("Upload failed. Please check internet connection.")
                }
            } catch (e: Exception) {
                e.printStackTrace()
                showErrorState("Error occurred: ${e.localizedMessage}")
            }
        }
    }

    private fun updateProgress(text: String, progress: Int) {
        progressText.text = text
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            progressBar.setProgress(progress, true)
        } else {
            progressBar.progress = progress
        }
    }

    private fun showErrorState(message: String) {
        progressLayout.visibility = View.GONE
        sendButton.isEnabled = true
        sendButton.visibility = View.VISIBLE
        cancelTextView.visibility = View.VISIBLE
        bottomSheetDialog.setCancelable(true)
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }

    private suspend fun transcodeImages() = withContext(Dispatchers.IO) {
        processedFiles.clear()
        val cacheDir = cacheDir
        for ((index, uri) in imageUris.withIndex()) {
            try {
                contentResolver.openInputStream(uri)?.use { input ->
                    val original = BitmapFactory.decodeStream(input)
                    if (original != null) {
                        // Transcode / force convert to sRGB and save as compressed JPEG (85% quality)
                        val srgbBitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val colorSpace = original.colorSpace
                            if (colorSpace != null && colorSpace != ColorSpace.get(ColorSpace.Named.SRGB)) {
                                val dest = Bitmap.createBitmap(original.width, original.height, Bitmap.Config.ARGB_8888)
                                val canvas = Canvas(dest)
                                val paint = Paint().apply {
                                    isAntiAlias = true
                                    isFilterBitmap = true
                                }
                                canvas.drawBitmap(original, 0f, 0f, paint)
                                dest
                            } else {
                                original
                            }
                        } else {
                            original
                        }

                        val outFile = File(cacheDir, "transcoded_share_${UUID.randomUUID()}_$index.jpg")
                        FileOutputStream(outFile).use { output ->
                            srgbBitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
                        }
                        processedFiles.add(outFile)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private suspend fun uploadProcessedImages(): Boolean = withContext(Dispatchers.IO) {
        if (processedFiles.isEmpty()) return@withContext false

        // Read the user's saved global playback profile (written by Flutter's
        // FrameSettingsStore._syncGlobalPlaybackDefaults via SharedPreferences).
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val displaySeconds = try {
            prefs.getInt("flutter.global_display_seconds", 600)
        } catch (e: ClassCastException) {
            try {
                prefs.getLong("flutter.global_display_seconds", 600L).toInt()
            } catch (e2: ClassCastException) {
                (prefs.all["flutter.global_display_seconds"] as? Number)?.toInt() ?: 600
            }
        }
        val playbackMode = prefs.getString("flutter.global_playback_mode", "sequential") ?: "sequential"
        val durationType = prefs.getString("flutter.global_duration_type", "unlimited") ?: "unlimited"
        val intervalMin = if (displaySeconds > 0) displaySeconds / 60 else 10
        val strategyVal = if (playbackMode == "random") 2 else 1
        val durationHrs = parseDurationHours(durationType)

        val client = OkHttpClient()
        val targetFrames = pairedFrames.filter { selectedFrameIds.contains(it.id) }
        if (targetFrames.isEmpty()) return@withContext false

        var totalUploads = processedFiles.size * targetFrames.size
        var completed = 0

        for (frame in targetFrames) {
            val uploadedImageIds = mutableListOf<String>()
            val apiBase = frame.apiUrl.removeSuffix("/")
            val cleanMac = frame.mac.replace(Regex("[^0-9a-fA-F]"), "").uppercase()
            val macSlug = if (cleanMac.length >= 12) cleanMac.takeLast(12) else cleanMac
            
            // Matches iOS skip_play logic: skip_play = false for single image, skip_play = true for multiple images + publishing slideshow strategy.
            val isMultiple = processedFiles.size > 1

            for ((index, file) in processedFiles.withIndex()) {
                val fileBytes = file.readBytes()
                val checksum = sha256(fileBytes)
                
                withContext(Dispatchers.Main) {
                    updateProgress("Uploading photo ${index + 1}/${processedFiles.size} to ${frame.name}...", 30 + (40 * completed / totalUploads))
                }

                val mediaType = "image/jpeg".toMediaTypeOrNull()
                val fileBody = file.asRequestBody(mediaType)
                
                val requestBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("mac", macSlug)
                    .addFormDataPart("device_id", frame.id)
                    .addFormDataPart("checksum", checksum)
                    .addFormDataPart("size", fileBytes.size.toString())
                    .addFormDataPart("app_platform", "flutter")
                    .addFormDataPart("slideshow_style", "classic")
                    .addFormDataPart("display_seconds", displaySeconds.toString())
                    .addFormDataPart("transport", "wifi")
                    .addFormDataPart("skip_play", if (isMultiple) "true" else "false")
                    .addFormDataPart("photo", file.name, fileBody)
                    .build()

                val requestBuilder = Request.Builder()
                    .url("$apiBase/api/frames/$macSlug/upload")
                    .post(requestBody)
                    
                val pairingTokenToSend = if (frame.pairingToken.isNotEmpty() && !frame.pairingToken.equals("null", ignoreCase = true)) {
                    frame.pairingToken
                } else {
                    "framepass2026"
                }
                requestBuilder.header("x-pairing-token", pairingTokenToSend)

                val cleanAuthToken = authToken.trim()
                if (cleanAuthToken.isNotEmpty() && !cleanAuthToken.equals("null", ignoreCase = true)) {
                    requestBuilder.header("Authorization", "Bearer $cleanAuthToken")
                }

                try {
                    val response = client.newCall(requestBuilder.build()).execute()
                    val bodyString = response.body?.string() ?: ""
                    if (response.isSuccessful) {
                        val json = JSONObject(bodyString)
                        if (json.optBoolean("ok", false)) {
                            // Extract vpsSlideshowImageId logic (framePlayBasename, storedPath or imageUrl)
                            var vpsId = json.optString("frame_play_basename", "").trim()
                            if (vpsId.isEmpty()) {
                                val storedPath = json.optString("stored_path", "").trim()
                                if (storedPath.isNotEmpty()) {
                                    vpsId = storedPath.split("/").last()
                                }
                            }
                            if (vpsId.isEmpty()) {
                                val imageUrl = json.optString("image_url", "").trim()
                                if (imageUrl.isNotEmpty()) {
                                    vpsId = imageUrl.split("/").last()
                                }
                            }
                            if (vpsId.isEmpty()) {
                                vpsId = json.optString("checksum_sha256", "").trim()
                            }
                            if (vpsId.isNotEmpty()) {
                                uploadedImageIds.add(vpsId)
                            }
                        }
                    } else {
                        withContext(Dispatchers.Main) {
                            Toast.makeText(this@ShareActivity, "HTTP Error ${response.code}: $bodyString", Toast.LENGTH_LONG).show()
                        }
                        return@withContext false
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@ShareActivity, "Net error: ${e.message}", Toast.LENGTH_LONG).show()
                    }
                    return@withContext false
                }
                completed++
            }

            // Publish slideshow strategy for multi-image publish matching iOS logic
            if (isMultiple && uploadedImageIds.isNotEmpty()) {
                withContext(Dispatchers.Main) {
                    updateProgress("Publishing playlist to ${frame.name}...", 70 + (20 * completed / totalUploads))
                }

                val nowMs = System.currentTimeMillis()
                val endtime = if (durationHrs > 0) (nowMs + durationHrs.toLong() * 3600 * 1000).toString() else ""
                
                val publishBody = JSONObject().apply {
                    put("imageIds", JSONArray(uploadedImageIds))
                    put("intervalMinutes", intervalMin)
                    put("strategy", strategyVal)
                    put("begintime", nowMs.toString())
                    put("endtime", endtime)
                    put("idle", 1)
                    put("skipPlay", true)
                }

                val publishRequest = Request.Builder()
                    .url("$apiBase/api/frames/$macSlug/slideshow")
                    .post(publishBody.toString().toRequestBody("application/json".toMediaTypeOrNull()))
                    
                val pairingTokenToSend = if (frame.pairingToken.isNotEmpty() && !frame.pairingToken.equals("null", ignoreCase = true)) {
                    frame.pairingToken
                } else {
                    "framepass2026"
                }
                publishRequest.header("x-pairing-token", pairingTokenToSend)

                val cleanAuthToken = authToken.trim()
                if (cleanAuthToken.isNotEmpty() && !cleanAuthToken.equals("null", ignoreCase = true)) {
                    publishRequest.header("Authorization", "Bearer $cleanAuthToken")
                }

                try {
                    val response = client.newCall(publishRequest.build()).execute()
                    if (!response.isSuccessful) {
                        // Log failure but proceed as images were successfully uploaded
                        System.err.println("Slideshow publish failed: ${response.code}")
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        return@withContext true
    }

    private fun sha256(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(bytes)
        return hash.joinToString("") { "%02x".format(it) }
    }

    /** Parses the `duration_type` value (e.g. `unlimited`, `6h`, `2d`) into hours. */
    private fun parseDurationHours(type: String): Int {
        var v = type.trim().lowercase()
        if (v.isEmpty() || v == "unlimited" || v == "0") return 0
        return if (v.endsWith("h")) {
            v.dropLast(1).toIntOrNull() ?: 0
        } else if (v.endsWith("d")) {
            (v.dropLast(1).toIntOrNull() ?: 0) * 24
        } else {
            v.toIntOrNull() ?: 0
        }
    }

    private fun cleanupTempFiles() {
        for (file in processedFiles) {
            try {
                if (file.exists()) {
                    file.delete()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        processedFiles.clear()
    }
}
