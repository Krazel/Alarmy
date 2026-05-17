package com.dmkr.alarma;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;

public class AlarmReceiver extends BroadcastReceiver {
    private static final String CHANNEL_ID = "alarma-ring";

    @Override
    public void onReceive(Context context, Intent intent) {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        Uri sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);

        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Alarma",
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setSound(sound, new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build());
            manager.createNotificationChannel(channel);
        }

        android.app.Notification notification = new android.app.Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Alarma")
            .setContentText("Es hora.")
            .setPriority(android.app.Notification.PRIORITY_MAX)
            .setCategory(android.app.Notification.CATEGORY_ALARM)
            .setAutoCancel(true)
            .build();

        manager.notify(2001, notification);
    }
}
