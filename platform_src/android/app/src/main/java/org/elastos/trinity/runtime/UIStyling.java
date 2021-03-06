package org.elastos.trinity.runtime;

import android.graphics.Color;

class UIStyling {
    static int popupMainTextColor = Color.parseColor("#FFFFFF");
    static int popupMainBackgroundColor = Color.parseColor("#FFFFFF");
    static int popupSecondaryBackgroundColor = Color.parseColor("#FFFFFF");

    static void prepare(boolean useDarkMode) {
        if (useDarkMode) {
            // DARK MODE
            popupMainTextColor = Color.parseColor("#fdfeff");
            popupMainBackgroundColor = Color.parseColor("#72738E");
            popupSecondaryBackgroundColor = Color.parseColor("#393948");
        }
        else {
            // LIGHT MODE
            popupMainTextColor = Color.parseColor( "#161740");
            popupMainBackgroundColor = Color.parseColor("#F0F0F0");
            popupSecondaryBackgroundColor = Color.parseColor("#FFFFFF");
        }
    }
}
