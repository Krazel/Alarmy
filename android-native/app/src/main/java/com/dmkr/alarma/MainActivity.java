package com.dmkr.alarma;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.TimePicker;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;

public class MainActivity extends Activity {
    private TextView status;
    private TimePicker picker;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(buildUi());
        ensureNotificationPermission();
    }

    private View buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(36, 48, 36, 36);
        root.setBackgroundColor(0xFFFFF7E8);

        TextView title = new TextView(this);
        title.setText("Alarma");
        title.setTextSize(36);
        title.setTextColor(0xFF2B2118);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText("Version Android nativa con AlarmManager.");
        subtitle.setTextSize(16);
        subtitle.setTextColor(0xFF6F6256);
        subtitle.setPadding(0, 8, 0, 24);
        root.addView(subtitle);

        picker = new TimePicker(this);
        picker.setIs24HourView(true);
        root.addView(picker);

        Button schedule = new Button(this);
        schedule.setText("Programar alarma");
        schedule.setAllCaps(false);
        schedule.setOnClickListener(v -> scheduleAlarm());
        root.addView(schedule);

        Button cancel = new Button(this);
        cancel.setText("Cancelar alarma");
        cancel.setAllCaps(false);
        cancel.setOnClickListener(v -> cancelAlarm());
        root.addView(cancel);

        status = new TextView(this);
        status.setText("Sin alarma activa");
        status.setTextSize(18);
        status.setTextColor(0xFF2B2118);
        status.setPadding(0, 24, 0, 0);
        root.addView(status);

        return root;
    }

    private void scheduleAlarm() {
        AlarmManager manager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM));
            status.setText("Permite alarmas exactas y vuelve a programarla.");
            return;
        }

        Calendar target = Calendar.getInstance();
        target.set(Calendar.HOUR_OF_DAY, picker.getHour());
        target.set(Calendar.MINUTE, picker.getMinute());
        target.set(Calendar.SECOND, 0);
        target.set(Calendar.MILLISECOND, 0);
        if (target.getTimeInMillis() <= System.currentTimeMillis()) {
            target.add(Calendar.DAY_OF_YEAR, 1);
        }

        PendingIntent pending = alarmIntent();
        manager.setAlarmClock(new AlarmManager.AlarmClockInfo(target.getTimeInMillis(), pending), pending);
        String formatted = new SimpleDateFormat("HH:mm", Locale.US).format(target.getTime());
        status.setText("Alarma programada a las " + formatted);
    }

    private void cancelAlarm() {
        AlarmManager manager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        manager.cancel(alarmIntent());
        status.setText("Alarma cancelada");
    }

    private PendingIntent alarmIntent() {
        Intent intent = new Intent(this, AlarmReceiver.class);
        return PendingIntent.getBroadcast(
            this,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private void ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 11);
        }
    }
}
