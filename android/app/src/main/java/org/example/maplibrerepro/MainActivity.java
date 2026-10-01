package org.example.maplibrerepro;

import android.app.Activity;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.ByteArrayOutputStream;
import org.maplibre.android.MapLibre;
import org.maplibre.android.camera.CameraPosition;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.maps.Style;
import org.maplibre.android.snapshotter.MapSnapshotter;

/** Reuses one Snapshotter, with one request in flight and a moving camera. */
public final class MainActivity extends Activity {
    private static final String TAG = "SnapshotRepro";
    private static final double[][] ROUTE = {
        {33.3595,35.1692}, {33.3612,35.1700}, {33.3630,35.1700},
        {33.3640,35.1688}, {33.3640,35.1670}, {33.3620,35.1665},
        {33.3600,35.1674}, {33.3595,35.1692}
    };
    private final Handler handler = new Handler(Looper.getMainLooper());
    private MapSnapshotter snapshotter;
    private TextView status;
    private ImageView preview;
    private Bitmap displayed;
    private long started;
    private int frames;
    private boolean running;
    private final Runnable next = this::render;
    private final Runnable timeout = () -> {
        stop();
        report("ERROR: snapshot timed out after 30 seconds");
    };

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        MapLibre.getInstance(getApplicationContext());
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(16, 48, 16, 16);
        status = new TextView(this);
        layout.addView(status);
        Button start = new Button(this);
        start.setText("Start 120 snapshots");
        start.setOnClickListener(v -> start());
        layout.addView(start);
        Button stop = new Button(this);
        stop.setText("Stop");
        stop.setOnClickListener(v -> { stop(); report("Stopped after " + frames + " frames"); });
        layout.addView(stop);
        preview = new ImageView(this);
        preview.setAdjustViewBounds(true);
        layout.addView(preview);
        TextView attribution = new TextView(this);
        attribution.setText("OpenFreeMap · OpenMapTiles · © OpenStreetMap contributors");
        layout.addView(attribution);
        setContentView(layout);
        report("Ready: 480x240, pixel ratio 1, zoom 15, pitch 40, JPEG 50");
        if (getIntent().getBooleanExtra("autoStart", false)) start();
    }

    private void start() {
        if (running) return;
        String styleUrl = getIntent().getStringExtra("styleUrl");
        if (styleUrl == null) styleUrl = "https://tiles.openfreemap.org/styles/bright";
        snapshotter = new MapSnapshotter(getApplicationContext(),
            new MapSnapshotter.Options(480, 240).withPixelRatio(1f)
                .withStyleBuilder(new Style.Builder().fromUri(styleUrl)));
        frames = 0;
        started = SystemClock.elapsedRealtime();
        running = true;
        report("START style=" + styleUrl);
        handler.post(next);
    }

    private void render() {
        if (!running) return;
        double phase = ((SystemClock.elapsedRealtime() - started) % 120000) / 120000.0;
        double position = phase * (ROUTE.length - 1);
        int i = (int) position;
        double f = position - i;
        double lon = ROUTE[i][0] + (ROUTE[i+1][0] - ROUTE[i][0]) * f;
        double lat = ROUTE[i][1] + (ROUTE[i+1][1] - ROUTE[i][1]) * f;
        snapshotter.setCameraPosition(new CameraPosition.Builder()
            .target(new LatLng(lat, lon)).zoom(15).tilt(40).bearing(phase * 360).build());
        long frameStarted = SystemClock.elapsedRealtime();
        report("REQUEST " + (frames + 1) + " bearing=" + (phase * 360));
        handler.postDelayed(timeout, 30000);
        snapshotter.start(snapshot -> {
            handler.removeCallbacks(timeout);
            if (!running) { snapshot.getBitmap().recycle(); return; }
            Bitmap bitmap = snapshot.getBitmap();
            ByteArrayOutputStream jpeg = new ByteArrayOutputStream();
            boolean encoded = bitmap.compress(Bitmap.CompressFormat.JPEG, 50, jpeg);
            preview.setImageBitmap(bitmap);
            if (displayed != null) displayed.recycle();
            displayed = bitmap;
            frames++;
            report("FRAME " + frames + " durationMs=" + (SystemClock.elapsedRealtime() - frameStarted)
                + " jpegBytes=" + jpeg.size() + " encoded=" + encoded);
            if (!encoded || frames >= 120) {
                stop();
                report(encoded ? "COMPLETE: 120 snapshots, no crash observed" : "ERROR: JPEG encoding failed");
            } else {
                handler.postDelayed(next, Math.max(1, 1000 - (SystemClock.elapsedRealtime() - frameStarted)));
            }
        }, error -> {
            stop();
            report("ERROR: " + error);
        });
    }

    private void report(String message) { status.setText(message); Log.i(TAG, message); }
    private void stop() {
        running = false;
        handler.removeCallbacks(next);
        handler.removeCallbacks(timeout);
        if (snapshotter != null) { snapshotter.cancel(); snapshotter = null; }
    }
    @Override protected void onStop() { stop(); super.onStop(); }
    @Override protected void onDestroy() {
        preview.setImageDrawable(null);
        if (displayed != null) displayed.recycle();
        super.onDestroy();
    }
}
