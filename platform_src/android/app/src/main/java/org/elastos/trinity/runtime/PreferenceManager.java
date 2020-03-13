package org.elastos.trinity.runtime;

import android.content.Context;
import android.content.res.AssetManager;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.InputStream;
import java.util.Iterator;
import java.util.Locale;

public class PreferenceManager {
    private static PreferenceManager preferenceManager;

    private JSONObject defaultPreferences = new JSONObject();
    ManagerDBAdapter dbAdapter = null;

    PreferenceManager() {
        dbAdapter = AppManager.getShareInstance().getDBAdapter();
        try {
            parsePreferences();
        } catch (Exception e) {
            e.printStackTrace();
        }
        PreferenceManager.preferenceManager = this;
    }

    public static PreferenceManager getShareInstance() {
        if (PreferenceManager.preferenceManager == null) {
            PreferenceManager.preferenceManager = new PreferenceManager();
        }
        return PreferenceManager.preferenceManager;
    }

    public void parsePreferences() throws Exception {
        AssetManager manager = AppManager.getShareInstance().activity.getAssets();
        InputStream inputStream = manager.open("www/config/preferences.json");

        defaultPreferences = Utility.getJsonFromFile(inputStream);
    }

    private Object getDefaultValue(String key) throws Exception {
        Object value = null;
        if (defaultPreferences.has(key)) {
            value = defaultPreferences.get(key);
        }
        return value;
    }

    public JSONObject getPreference(String key) throws Exception  {
        Object defaultValue = getDefaultValue(key);
        if (defaultValue == null) {
            throw new Exception("getPreference error: no such preference!");
        }

        JSONObject ret = dbAdapter.getPreference(key);

        if (ret == null) {
            ret = new JSONObject();
            ret.put("key", key);
            ret.put("value", defaultValue);
        }

        if (key.equals("locale.language") && ret.getString("value").equals("native system")) {
            ret.put("value", Locale.getDefault().getLanguage());
        }

        return ret;
    }

    public JSONObject getPreferences() throws Exception {
        JSONObject values = dbAdapter.getPreferences();
        Iterator keys = defaultPreferences.keys();
        while (keys.hasNext()) {
            String key = (String)keys.next();
            if (!values.has(key)) {
                Object value = defaultPreferences.get(key);
                values.put(key, value);
            }

            if (key.equals("locale.language") && values.getString(key).equals("native system")) {
                values.put(key, Locale.getDefault().getLanguage());
            }
        }
        return values;
    }

    public void setPreference(String key, Object value) throws Exception {
        Object defaultValue = getDefaultValue(key);
        if (defaultValue == null) {
            throw new Exception("setPreference error: no such preference!");
        }

        if (dbAdapter.setPreference(key, value) < 1) {
            throw new Exception("setPreference error: write db error!");
        }

//        if (key == "developer.mode") {
//            Boolean isMode = false;
//            if (value != null) {
//                isMode = Boolean.getBoolean(value);
//            }
//
//            if (isMode) {
//                CLIService.getShareInstance().start();
//            }
//            else {
//                CLIService.getShareInstance().stop();
//            }
//        }

        JSONObject data = new JSONObject();
        data.put("key", key);
        data.put("value", value);
        JSONObject json = new JSONObject();
        json.put("action", "preferenceChanged");
        json.put("data", data);
        AppManager.getShareInstance().broadcastMessage(AppManager.MSG_TYPE_IN_REFRESH,
                json.toString() , "system");
    }

    public Boolean getDeveloperMode() {
        JSONObject value = null;
        Boolean ret = false;
        try {
            value = getPreference("developer.mode");
            if (value != null ) {
                ret = Boolean.getBoolean(value.getString("value"));
            }
        }
        catch (Exception e){
            e.printStackTrace();
        }


        return ret;
    }

    public void setDeveloperMode(Boolean value) {
        try {
            setPreference("developer.mode", value);
        }
        catch (Exception e){
            e.printStackTrace();
        }
    }

    public String getCurrentLocale() throws Exception {
        JSONObject value = getPreference("locale.language");
        String ret = value.getString("value");
        if (ret.equals("native system")) {
            ret = Locale.getDefault().getLanguage();
        }
        return ret;
    }

    public void setCurrentLocale(String code) throws Exception {
        setPreference("locale.language", code);
        AppManager.getShareInstance().broadcastMessage(AppManager.MSG_TYPE_IN_REFRESH,
                "{\"action\":\"currentLocaleChanged\", \"code\":\"" + code + "\"}", AppManager.LAUNCHER);
    }
}
