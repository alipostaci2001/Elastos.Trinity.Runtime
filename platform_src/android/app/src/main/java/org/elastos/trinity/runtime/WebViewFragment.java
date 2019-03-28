/*
 * Copyright (c) 2018 Elastos Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package org.elastos.trinity.runtime;

import android.app.Activity;
import android.support.v4.app.Fragment;
import android.content.Context;
import android.graphics.Color;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaInterfaceImpl;
import org.apache.cordova.CordovaPreferences;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaWebViewEngine;
import org.apache.cordova.CordovaWebViewImpl;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginEntry;
import org.json.JSONException;

import java.util.ArrayList;

/**
 * This is the Home section fragment that implements {@link CordovaInterface} and uses a layout that contains
 * a {@link CordovaWebView}.
 *
 */
public class WebViewFragment extends Fragment {
    private static final String TAG = "WebViewFragment";

    protected static CordovaPreferences cfgPreferences;
    protected static ArrayList<PluginEntry> cfgPluginEntries;

    protected Activity activity;

    // Keep app running when pause is received. (default = true)
    // If true, then the JavaScript and native code continue to run in the background
    // when another application (activity) is started.
    protected boolean keepRunning = true;

    //Instance of the actual Cordova WebView
    protected CordovaWebView appView;
    protected int viewId = 100;
    protected CordovaPreferences preferences;
    protected ArrayList<PluginEntry> pluginEntries;
    protected CordovaInterfaceImpl cordovaInterface;
    protected String launchUrl;
    protected AppBasePlugin basePlugin;
    protected String id;

    /**
     * Returns a new instance of this fragment for the given section
     * number.
     */

    @Override
    /**
     * Initialize the {@link CordovaWebView} and load its start URL.
     *
     * The fragment inflator needs to be cloned first to use an instance of {@link CordovaContext} instead.  This
     * alternate context object implements the {@link CordovaInterface} as well and acts as a proxy between the activity
     * and fragment for the {@link CordovaWebView}.  The actual {@link CordovaWebView} is defined in the home_view_frag.xml layout
     * and has an id of <b>aemWebView</b>.
     */
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
            Bundle savedInstanceState) {
        activity = AppManager.appManager.activity;

        loadConfig();

        cordovaInterface = makeCordovaInterface();
        if (savedInstanceState != null) {
            cordovaInterface.restoreInstanceState(savedInstanceState);
        }

        loadUrl(launchUrl);

        return appView.getView();
    }

    protected void loadConfig() {

    }

    protected void init() {
        appView = makeWebView();
        createViews();
        if (!appView.isInitialized()) {
            appView.init(cordovaInterface, pluginEntries, preferences);
        }
        cordovaInterface.onCordovaInit(appView.getPluginManager());
    }


    protected void createViews() {
        //Why are we setting a constant as the ID? This should be investigated
        appView.getView().setId(viewId++);
        appView.getView().setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

//        getActivity().setContentView(appView.getView());

        if (preferences.contains("BackgroundColor")) {
            try {
                int backgroundColor = preferences.getInteger("BackgroundColor", Color.BLACK);
                // Background of activity:
                appView.getView().setBackgroundColor(backgroundColor);
            }
            catch (NumberFormatException e){
                e.printStackTrace();
            }
        }

        appView.getView().requestFocusFromTouch();
    }

    protected CordovaWebView makeWebView() {
        return new CordovaWebViewImpl(makeWebViewEngine());
    }

    protected CordovaWebViewEngine makeWebViewEngine() {
        return CordovaWebViewImpl.createEngine(getActivity(), preferences);
    }

    protected CordovaInterfaceImpl makeCordovaInterface() {
        return new CordovaInterfaceImpl(activity) {
            @Override
            public Object onMessage(String id, Object data) {
                // Plumb this to CordovaActivity.onMessage for backwards compatibility
                return WebViewFragment.this.onMessage(id, data);
            }
        };
    }

    /**
     * Load the url into the webview.
     */
    public void loadUrl(String url) {
        if (appView == null) {
            init();
        }

        // If keepRunning
        this.keepRunning = preferences.getBoolean("KeepRunning", true);

        appView.loadUrlIntoView(url, true);
    }

    /**
     * Called when the system is about to start resuming a previous activity.
     */
    @Override
    public void onPause() {
        super.onPause();
        LOG.d(TAG, "Paused the fragment.");

        if (this.appView != null) {
            // CB-9382 If there is an activity that started for result and main activity is waiting for callback
            // result, we shoudn't stop WebView Javascript timers, as activity for result might be using them
//            boolean keepRunning = this.keepRunning || this.cordovaInterface.activityResultCallback != null;
            this.appView.handlePause(keepRunning);
        }
    }

    /**
     * Called when the activity will start interacting with the user.
     */
    @Override
    public void onResume() {
        super.onResume();
        LOG.d(TAG, "Resumed the fragment.");

        if (this.appView == null) {
            return;
        }
//        // Force window to have focus, so application always
//        // receive user input. Workaround for some devices (Samsung Galaxy Note 3 at least)
//        this.getWindow().getDecorView().requestFocus();

        this.appView.handleResume(this.keepRunning);
    }

    /**
     * Called when the activity is no longer visible to the user.
     */
    @Override
    public void onStop() {
        super.onStop();
        LOG.d(TAG, "Stopped the fragment.");

        if (this.appView == null) {
            return;
        }
        this.appView.handleStop();
    }

    /**
     * Called when the activity is becoming visible to the user.
     */
    @Override
    public void onStart() {
        super.onStart();
        LOG.d(TAG, "Started the fragment.");

        if (this.appView == null) {
            return;
        }
        this.appView.handleStart();
    }

    /**
     * The final call you receive before your activity is destroyed.
     */
    @Override
    public void onDestroy() {
        LOG.d(TAG, "WebViewFragment.onDestroy()");
        super.onDestroy();

        if (this.appView != null) {
            appView.handleDestroy();
        }
    }

    /*
     * Hook in Cordova for menu plugins
     */
    @Override
    public void onCreateOptionsMenu (Menu menu,
                              MenuInflater inflater) {
        if (appView != null) {
            appView.getPluginManager().postMessage("onCreateOptionsMenu", menu);
        }
        super.onCreateOptionsMenu(menu, inflater);
    }

    @Override
    public void onPrepareOptionsMenu(Menu menu) {
        if (appView != null) {
            appView.getPluginManager().postMessage("onPrepareOptionsMenu", menu);
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (appView != null) {
            appView.getPluginManager().postMessage("onOptionsItemSelected", item);
        }
        return true;
    }

    @Override
    public Context getContext() {
        return activity;
    }

    /**
     * Called when a message is sent to plugin.
     *
     * @param id   The message id
     * @param data The message data
     * @return Object or null
     */
    public Object onMessage(String id, Object data) {
//        if ("onReceivedError".equals(id)) {
//            JSONObject d = (JSONObject) data;
//            try {
//                this.onReceivedError(d.getInt("errorCode"), d.getString("description"), d.getString("url"));
//            } catch (JSONException e) {
//                e.printStackTrace();
//            }
//        }
        return null;
    }

    public void onRequestPermissionResult(int requestCode, String permissions[],
                                          int[] grantResults) throws JSONException {
        cordovaInterface.onRequestPermissionResult(requestCode, permissions, grantResults);
    }
}