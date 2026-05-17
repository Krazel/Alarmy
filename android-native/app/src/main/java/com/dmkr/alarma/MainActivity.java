package com.dmkr.alarma;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.TimePicker;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

public class MainActivity extends Activity {
    static final String EXTRA_RING = "com.dmkr.alarma.RING";
    private static final String PREFS = "hiphop_alarm";
    private static final String[] SOUND_IDS = {"sunrise", "sunset", "piano", "rain", "sea", "vinyl", "bass"};
    private static final String[] SOUND_NAMES = {"Amanecer", "Atardecer", "Piano", "Lluvia", "Mar", "Vinilo", "Bajo"};
    private SharedPreferences prefs;
    private Ringtone ringtone;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        ensureDefaults();
        ensureNotificationPermission();
        if (getIntent().getBooleanExtra(EXTRA_RING, false)) {
            showRinging();
        } else {
            showHome();
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        if (intent.getBooleanExtra(EXTRA_RING, false)) showRinging();
    }

    private void ensureDefaults() {
        if (!prefs.contains("label")) {
            prefs.edit()
                .putString("label", "Noche")
                .putInt("hour", 7)
                .putInt("minute", 30)
                .putBoolean("enabled", true)
                .putBoolean("sunset", true)
                .putBoolean("animations", true)
                .putBoolean("randomSound", true)
                .putBoolean("motionSnooze", false)
                .putInt("snooze", 9)
                .putStringSet("sounds", new HashSet<String>() {{
                    add("sunrise"); add("sunset"); add("piano"); add("rain");
                }})
                .apply();
        }
    }

    private void showHome() {
        stopSound();
        boolean sunset = prefs.getBoolean("sunset", true);
        FrameLayout screen = backdrop(sunset);
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = vertical();
        root.setPadding(dp(22), dp(42), dp(22), dp(26));
        scroll.addView(root);
        screen.addView(scroll);

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout titleBlock = vertical();
        TextView title = text("Alarma", 46, colorText(sunset), true);
        title.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        titleBlock.addView(title);
        titleBlock.addView(text("Despierta con calma. Duerme mejor.", 15, colorSecondary(sunset), false));
        header.addView(titleBlock, new LinearLayout.LayoutParams(0, -2, 1));
        header.addView(iconButton(prefs.getBoolean("animations", true) ? "✦" : "Ⅱ", v -> {
            prefs.edit().putBoolean("animations", !prefs.getBoolean("animations", true)).apply();
            showHome();
        }));
        header.addView(iconButton(sunset ? "☾" : "☀", v -> {
            prefs.edit().putBoolean("sunset", !sunset).apply();
            showHome();
        }));
        root.addView(header);

        root.addView(heroCard(sunset));
        root.addView(primaryButton("Iniciar noche", v -> showActive()));
        root.addView(rowButton("Editar alarma", "Hora, sonidos, posponer y opciones", v -> showEditor()));
        root.addView(rowButton("Programar alarma", "Crear alarma exacta en Android", v -> scheduleAlarm()));
        root.addView(rowButton("Cancelar alarma", "Eliminar alarma programada", v -> cancelAlarm()));

        setContentView(screen);
    }

    private View heroCard(boolean sunset) {
        LinearLayout card = vertical();
        card.setPadding(dp(18), dp(18), dp(18), dp(18));
        card.setBackgroundColor(sunset ? 0xAAFFFFFF : 0xAA031116);
        LinearLayout.LayoutParams lp = margins(-1, -2, 0, 28, 0, 20);
        card.setLayoutParams(lp);

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = text("♬", 34, colorPrimary(sunset), true);
        icon.setGravity(Gravity.CENTER);
        top.addView(icon, new LinearLayout.LayoutParams(dp(54), dp(54)));
        LinearLayout info = vertical();
        info.addView(text(prefs.getString("label", "Noche"), 22, colorText(sunset), true));
        info.addView(text(soundSummary(), 14, colorSecondary(sunset), false));
        top.addView(info, new LinearLayout.LayoutParams(0, -2, 1));
        top.addView(iconButton("✎", v -> showEditor()));
        card.addView(top);

        TextView time = text(timeText(), 78, colorText(sunset), true);
        time.setGravity(Gravity.CENTER);
        time.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        card.addView(time, margins(-1, -2, 0, 20, 0, 0));

        TextView caption = text("Descansa", 20, colorPrimary(sunset), true);
        caption.setGravity(Gravity.CENTER);
        card.addView(caption);

        TextView status = text(prefs.getBoolean("enabled", true) ? "Alarma activa" : "Alarma pausada", 15, colorSecondary(sunset), false);
        status.setGravity(Gravity.CENTER);
        card.addView(status, margins(-1, -2, 0, 8, 0, 0));
        return card;
    }

    private void showEditor() {
        boolean sunset = prefs.getBoolean("sunset", true);
        FrameLayout screen = backdrop(sunset);
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = vertical();
        root.setPadding(dp(22), dp(42), dp(22), dp(28));
        scroll.addView(root);
        screen.addView(scroll);

        root.addView(backHeader("Editar alarma", sunset, v -> showHome()));
        EditText label = new EditText(this);
        label.setText(prefs.getString("label", "Noche"));
        label.setHint("Nombre");
        label.setTextColor(colorText(sunset));
        label.setHintTextColor(colorSecondary(sunset));
        root.addView(label, margins(-1, -2, 0, 18, 0, 12));

        TimePicker picker = new TimePicker(this);
        picker.setIs24HourView(true);
        picker.setHour(prefs.getInt("hour", 7));
        picker.setMinute(prefs.getInt("minute", 30));
        root.addView(panel(picker, sunset));

        root.addView(sectionTitle("Sonidos", sunset));
        Set<String> selected = new HashSet<>(prefs.getStringSet("sounds", new HashSet<>()));
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(2);
        for (int i = 0; i < SOUND_IDS.length; i++) {
            String id = SOUND_IDS[i];
            CheckBox box = new CheckBox(this);
            box.setText(SOUND_NAMES[i]);
            box.setTextColor(colorText(sunset));
            box.setChecked(selected.contains(id));
            box.setOnCheckedChangeListener((buttonView, isChecked) -> {
                if (isChecked) selected.add(id); else selected.remove(id);
            });
            grid.addView(box, viewGroupMargin(dp(150), dp(48), 0, 0, 12, 8));
        }
        root.addView(panel(grid, sunset));

        CheckBox random = option("Sonido aleatorio", prefs.getBoolean("randomSound", true), sunset);
        CheckBox motion = option("Mueve el movil para posponer", prefs.getBoolean("motionSnooze", false), sunset);
        CheckBox enabled = option("Alarma activa", prefs.getBoolean("enabled", true), sunset);
        root.addView(random);
        root.addView(motion);
        root.addView(enabled);

        LinearLayout snooze = new LinearLayout(this);
        snooze.setGravity(Gravity.CENTER);
        int[] values = {5, 9, 15};
        for (int value : values) {
            Button b = smallButton(value + " min", sunset);
            b.setOnClickListener(v -> prefs.edit().putInt("snooze", value).apply());
            snooze.addView(b);
        }
        root.addView(sectionTitle("Posponer", sunset));
        root.addView(snooze);

        root.addView(primaryButton("Guardar", v -> {
            if (selected.isEmpty()) selected.add("sunrise");
            prefs.edit()
                .putString("label", label.getText().toString().trim().isEmpty() ? "Noche" : label.getText().toString().trim())
                .putInt("hour", picker.getHour())
                .putInt("minute", picker.getMinute())
                .putStringSet("sounds", selected)
                .putBoolean("randomSound", random.isChecked())
                .putBoolean("motionSnooze", motion.isChecked())
                .putBoolean("enabled", enabled.isChecked())
                .apply();
            if (enabled.isChecked()) scheduleAlarm();
            showHome();
        }));
        setContentView(screen);
    }

    private void showActive() {
        boolean sunset = prefs.getBoolean("sunset", true);
        FrameLayout screen = backdrop(sunset);
        LinearLayout root = vertical();
        root.setGravity(Gravity.CENTER);
        root.setPadding(dp(28), dp(48), dp(28), dp(48));
        screen.addView(root);
        root.addView(text("Noche activa", 20, colorSecondary(sunset), false));
        TextView time = text(timeText(), 72, colorText(sunset), true);
        time.setGravity(Gravity.CENTER);
        root.addView(time);
        root.addView(text(prefs.getString("label", "Noche"), 28, colorPrimary(sunset), true));
        root.addView(text("Mantendremos la alarma preparada.", 16, colorSecondary(sunset), false));
        root.addView(primaryButton("Terminar", v -> showHome()));
        setContentView(screen);
    }

    private void showRinging() {
        boolean sunset = prefs.getBoolean("sunset", true);
        playSound();
        FrameLayout screen = backdrop(sunset);
        LinearLayout root = vertical();
        root.setGravity(Gravity.CENTER);
        root.setPadding(dp(28), dp(48), dp(28), dp(48));
        screen.addView(root);
        root.addView(text(prefs.getBoolean("motionSnooze", false) ? "Mueve el movil\npara posponer" : "Alarma sonando", 32, colorText(sunset), true));
        root.addView(text(timeText(), 70, colorPrimary(sunset), true));
        LinearLayout actions = new LinearLayout(this);
        actions.setGravity(Gravity.CENTER);
        actions.addView(primaryButton("Posponer", v -> snooze()));
        actions.addView(smallButton("Terminar", sunset));
        actions.getChildAt(1).setOnClickListener(v -> {
            stopSound();
            cancelAlarm();
            showHome();
        });
        root.addView(actions);
        setContentView(screen);
    }

    private void scheduleAlarm() {
        AlarmManager manager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM));
            Toast.makeText(this, "Permite alarmas exactas y vuelve a programarla.", Toast.LENGTH_LONG).show();
            return;
        }
        Calendar target = Calendar.getInstance();
        target.set(Calendar.HOUR_OF_DAY, prefs.getInt("hour", 7));
        target.set(Calendar.MINUTE, prefs.getInt("minute", 30));
        target.set(Calendar.SECOND, 0);
        target.set(Calendar.MILLISECOND, 0);
        if (target.getTimeInMillis() <= System.currentTimeMillis()) target.add(Calendar.DAY_OF_YEAR, 1);
        PendingIntent pending = alarmIntent(1001, target.getTimeInMillis());
        manager.setAlarmClock(new AlarmManager.AlarmClockInfo(target.getTimeInMillis(), pending), pending);
        Toast.makeText(this, "Alarma programada a las " + new SimpleDateFormat("HH:mm", Locale.US).format(target.getTime()), Toast.LENGTH_SHORT).show();
    }

    private void snooze() {
        stopSound();
        Calendar target = Calendar.getInstance();
        target.add(Calendar.MINUTE, prefs.getInt("snooze", 9));
        ((AlarmManager) getSystemService(Context.ALARM_SERVICE)).setAlarmClock(
            new AlarmManager.AlarmClockInfo(target.getTimeInMillis(), alarmIntent(1002, target.getTimeInMillis())),
            alarmIntent(1002, target.getTimeInMillis())
        );
        showHome();
    }

    private void cancelAlarm() {
        AlarmManager manager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        manager.cancel(alarmIntent(1001, 0));
        manager.cancel(alarmIntent(1002, 0));
        Toast.makeText(this, "Alarma cancelada", Toast.LENGTH_SHORT).show();
    }

    private PendingIntent alarmIntent(int requestCode, long when) {
        Intent intent = new Intent(this, AlarmReceiver.class);
        intent.putExtra("label", prefs.getString("label", "Alarma"));
        return PendingIntent.getBroadcast(this, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private FrameLayout backdrop(boolean sunset) {
        FrameLayout frame = new FrameLayout(this);
        ImageView image = new ImageView(this);
        image.setImageResource(sunset ? R.drawable.sunset_background : R.drawable.night_background);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        frame.addView(image, new FrameLayout.LayoutParams(-1, -1));
        View overlay = new View(this);
        overlay.setBackgroundColor(sunset ? 0x55FFFFFF : 0x99000000);
        frame.addView(overlay, new FrameLayout.LayoutParams(-1, -1));
        if (prefs.getBoolean("animations", true)) frame.addView(beatLayer(sunset), new FrameLayout.LayoutParams(-1, -1));
        return frame;
    }

    private View beatLayer(boolean sunset) {
        LinearLayout bars = new LinearLayout(this);
        bars.setGravity(Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        bars.setPadding(0, 0, 0, dp(24));
        for (int i = 0; i < 18; i++) {
            TextView bar = new TextView(this);
            bar.setText("▌");
            bar.setTextSize(24 + (i % 5) * 5);
            bar.setTextColor(sunset ? 0x55FFB31F : 0x7731F0CB);
            bars.addView(bar);
        }
        return bars;
    }

    private void playSound() {
        stopSound();
        Uri uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
        ringtone = RingtoneManager.getRingtone(this, uri);
        if (ringtone != null) ringtone.play();
    }

    private void stopSound() {
        if (ringtone != null && ringtone.isPlaying()) ringtone.stop();
        ringtone = null;
    }

    private String timeText() {
        return String.format(Locale.US, "%02d:%02d", prefs.getInt("hour", 7), prefs.getInt("minute", 30));
    }

    private String soundSummary() {
        Set<String> selected = prefs.getStringSet("sounds", new HashSet<>());
        return (prefs.getBoolean("randomSound", true) ? "Aleatorio · " : "") + selected.size() + " sonidos";
    }

    private LinearLayout vertical() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        return layout;
    }

    private TextView text(String value, int sp, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(sp);
        view.setTextColor(color);
        if (bold) view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    private View backHeader(String title, boolean sunset, View.OnClickListener listener) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        ImageButton back = iconButton("‹", listener);
        row.addView(back);
        row.addView(text(title, 30, colorText(sunset), true));
        return row;
    }

    private ImageButton iconButton(String label, View.OnClickListener listener) {
        ImageButton button = new ImageButton(this);
        button.setBackgroundColor(0x55FFFFFF);
        button.setContentDescription(label);
        button.setOnClickListener(listener);
        return button;
    }

    private Button primaryButton(String label, View.OnClickListener listener) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(17);
        button.setBackgroundColor(0xFFE01B3C);
        button.setOnClickListener(listener);
        button.setPadding(dp(18), dp(10), dp(18), dp(10));
        return button;
    }

    private Button smallButton(String label, boolean sunset) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextColor(colorText(sunset));
        button.setBackgroundColor(0x55FFFFFF);
        return button;
    }

    private View rowButton(String title, String subtitle, View.OnClickListener listener) {
        LinearLayout row = vertical();
        row.setPadding(dp(16), dp(14), dp(16), dp(14));
        row.setBackgroundColor(0x66FFFFFF);
        row.addView(text(title, 18, 0xFF16110E, true));
        row.addView(text(subtitle, 14, 0xFF61574E, false));
        row.setOnClickListener(listener);
        row.setLayoutParams(margins(-1, -2, 0, 10, 0, 0));
        return row;
    }

    private View panel(View child, boolean sunset) {
        LinearLayout panel = vertical();
        panel.setPadding(dp(12), dp(12), dp(12), dp(12));
        panel.setBackgroundColor(sunset ? 0x88FFFFFF : 0x55000000);
        panel.addView(child);
        panel.setLayoutParams(margins(-1, -2, 0, 10, 0, 16));
        return panel;
    }

    private TextView sectionTitle(String value, boolean sunset) {
        return text(value, 20, colorText(sunset), true);
    }

    private CheckBox option(String label, boolean checked, boolean sunset) {
        CheckBox box = new CheckBox(this);
        box.setText(label);
        box.setTextColor(colorText(sunset));
        box.setChecked(checked);
        box.setPadding(0, dp(8), 0, dp(8));
        return box;
    }

    private LinearLayout.LayoutParams margins(int w, int h, int l, int t, int r, int b) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(w, h);
        lp.setMargins(dp(l), dp(t), dp(r), dp(b));
        return lp;
    }

    private GridLayout.LayoutParams viewGroupMargin(int w, int h, int l, int t, int r, int b) {
        GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
        lp.width = w;
        lp.height = h;
        lp.setMargins(dp(l), dp(t), dp(r), dp(b));
        return lp;
    }

    private int colorText(boolean sunset) { return sunset ? 0xFF16110E : Color.WHITE; }
    private int colorPrimary(boolean sunset) { return sunset ? 0xFFFFB31F : 0xFF31F0CB; }
    private int colorSecondary(boolean sunset) { return sunset ? 0xFF665340 : 0xFFB7D6D0; }
    private int dp(int value) { return (int) (value * getResources().getDisplayMetrics().density + 0.5f); }

    private void ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 11);
        }
    }
}
