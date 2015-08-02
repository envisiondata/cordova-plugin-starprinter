/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
 */
package com.star.printer;

import java.util.TimeZone;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.star.printer.StarBitmap;
import com.starmicronics.stario.StarIOPort;
import com.starmicronics.stario.StarIOPortException;
import com.starmicronics.stario.StarPrinterStatus;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaInterface;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.AlertDialog;
import android.app.AlertDialog.Builder;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.provider.Settings;

public class StarPrinter extends CordovaPlugin {

	public static final String CHECKSTATUS = "CheckStatus";
	public static final String CHECKFIRMWARE = "CheckFirmwareVersion";
	public static final String PRINTSAMPLERECEIPT = "PrintSampleReceipt";
	public static final String PRINTSIGNATURE = "PrintSignature";

	public static final String SET_USER_ID = "setUserId";
	public static final String DEBUG_MODE = "debugMode";

	public Boolean trackerStarted = false;
	public Boolean debugModeEnabled = false;
	private static Context mContext;

	/**
	 * Constructor.
	 */
	public StarPrinter() {
	}

	/**
	 * Sets the context of the Command. This can then be used to do things like
	 * get file paths associated with the Activity.
	 * 
	 * @param cordova
	 *            The context of the main Activity.
	 * @param webView
	 *            The CordovaWebView Cordova is running in.
	 */
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
	}

	/**
	 * Executes the request and returns PluginResult.
	 * 
	 * @param action
	 *            The action to execute.
	 * @param arguments
	 *            JSONArry of arguments for the plugin.
	 * @param callbackContext
	 *            The callback id used when calling back into JavaScript.
	 * @return True if the action was valid, false if not.
	 */
	public boolean execute(String action, JSONArray arguments,
            CallbackContext callbackContext) throws JSONException {
		mContext = this.cordova.getActivity();

		try {
			if (CHECKSTATUS.equals(action)) {
				Context context = this.cordova.getActivity();
				StarPrinter.CheckStatus(context, "BT:Star Micronics", "mini");
				callbackContext.success();
				return true;
			} else if (CHECKFIRMWARE.equals(action)) {

				Context context = this.cordova.getActivity();
				StarPrinter.CheckFirmwareVersion(context, "BT:Star Micronics",
						"mini");
				callbackContext.success();
				return true;
			} else if (PRINTSAMPLERECEIPT.equals(action)) {

				Context context = this.cordova.getActivity();
				StarPrinter.PrintSampleReceipt(context, "BT:Star Micronics",
						"mini", "3inch (80mm)");
				callbackContext.success();
				return true;
			} else if (PRINTSIGNATURE.equals(action)) {
				Context context = this.cordova.getActivity();		
				if(StarPrinter.PrintSignature(context, "BT:Star Micronics", "mini", "3inch (80mm)", arguments.toString()) == true){
					callbackContext.success();	
					return true;
				}
				else{

					callbackContext.error("Printer error! Please reprint.");
					return false;
				}				
			}
			callbackContext.error("Invalid action");
			return false;
		} catch (Exception e) {
			System.err.println("Exception: " + e.getMessage());
			callbackContext.error(e.getMessage());
			return false;
		}
	}

	// --------------------------------------------------------------------------
	// LOCAL METHODS
	// --------------------------------------------------------------------------

	/**
	 * This function shows how to read the MSR data(credit card) of a portable
	 * printer. The function first puts the printer into MSR read mode, then
	 * asks the user to swipe a credit card The function waits for a response
	 * from the user. The user can cancel MSR mode or have the printer read the
	 * card.
	 * 
	 * @param context
	 *            Activity for displaying messages to the user
	 * @param portName
	 *            Port name to use for communication. This should be
	 *            (TCP:<IPAddress> or BT:<Device pair name>)
	 * @param portSettings
	 *            Should be mini, the port settings mini is used for portable
	 *            printers
	 * @param strPrintArea
	 *            Printable area size, This should be ("2inch (58mm)" or
	 *            "3inch (80mm)")
	 */
	public static boolean PrintSignature(Context context, String portName,
			String portSettings, String strPrintArea, String sigArgs) {
		ArrayList<byte[]> list = new ArrayList<byte[]>();
		ArrayList<byte[]> al = new ArrayList<byte[]>();

		if (strPrintArea.equals("3inch (80mm)")) {
			byte[] outputByteBuffer = null;


			list = StarPrinter.PrintBitmap(context, portName, portSettings,
					sigArgs, 576, true, false);


			al.addAll(list);

			return sendCommand(context, portName, portSettings, al);
			// return true;

		}
		return false;
	}

	private static void ShowAlert(String Title, String Message) {
		Builder dialog = new AlertDialog.Builder(mContext);
		dialog.setNegativeButton("Ok", null);
		AlertDialog alert = dialog.create();
		alert.setTitle(Title);
		alert.setMessage(Message);
		alert.setCancelable(false);
		alert.show();

	}

	/**
	 * This function is used to print a java bitmap directly to a portable
	 * printer.
	 * 
	 * @param context
	 *            Activity for displaying messages to the user
	 * @param portName
	 *            Port name to use for communication. This should be
	 *            (TCP:<IPAddress> or BT:<Device pair name>)
	 * @param portSettings
	 *            Should be mini, the port settings mini is used for portable
	 *            printers
	 * @param source
	 *            The bitmap to convert to Star printer data for portable
	 *            printers
	 * @param maxWidth
	 *            The maximum width of the image to print. This is usually the
	 *            page width of the printer. If the image exceeds the maximum
	 *            width then the image is scaled down. The ratio is maintained.
	 */
	public static ArrayList<byte[]> PrintBitmap(Context context,
			String portName, String portSettings, String source, int maxWidth,
			boolean compressionEnable, boolean pageModeEnable) {
		ArrayList<byte[]> commands = new ArrayList<byte[]>();
		;


		Bitmap bitmap = null;
		try {
			bitmap = SigGen.redrawSignatureBMP(source);
		} catch (IOException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}

		StarBitmap starbitmap = new StarBitmap(bitmap, false, maxWidth);

		try {

			commands.add(starbitmap.getImageEscPosDataForPrinting(
					compressionEnable, pageModeEnable));

			return commands;
		} catch (StarIOPortException e) {
			ShowAlert("StarIOPortException", e.getMessage());
		} catch (Exception ex) {
			ShowAlert("PrintBitmap Exception", ex.getMessage());
		}
		return commands;
	}

	/**
	 * This function is used to print a java bitmap directly to a portable
	 * printer.
	 * 
	 * @param context
	 *            Activity for displaying messages to the user
	 * @param portName
	 *            Port name to use for communication. This should be
	 *            (TCP:<IPAddress> or BT:<Device pair name>)
	 * @param portSettings
	 *            Should be mini, the port settings mini is used for portable
	 *            printers
	 * @param res
	 *            The resources object containing the image data
	 * @param source
	 *            The resource id of the image data
	 * @param maxWidth
	 *            The maximum width of the image to print. This is usually the
	 *            page width of the printer. If the image exceeds the maximum
	 *            width then the image is scaled down. The ratio is maintained.
	 */
	public static void PrintBitmapImage(Context context, String portName,
			String portSettings, Resources res, int source, int maxWidth,
			boolean compressionEnable, boolean pageModeEnable) {
		ArrayList<byte[]> commands = new ArrayList<byte[]>();

		Bitmap bm = BitmapFactory.decodeResource(res, source);
		StarBitmap starbitmap = new StarBitmap(bm, false, maxWidth);

		try {

			commands.add(starbitmap.getImageEscPosDataForPrinting(
					compressionEnable, pageModeEnable));

			sendCommand(context, portName, portSettings, commands);
		} catch (StarIOPortException e) {
			Builder dialog = new AlertDialog.Builder(context);
			dialog.setNegativeButton("Ok", null);
			AlertDialog alert = dialog.create();
			alert.setTitle("Failure");
			alert.setMessage(e.getMessage());
			alert.setCancelable(false);
			alert.show();
		}
	}

	// Format the width of each column
	public static String padRight(String string, int length) {

		// Pad right
		if (string.length() > length) {
			string = string.substring(0, length - 1);
		}
		return String.format("%1$-" + length + "s", string);

	}

	public static String padLeft(String string, int length) {

		// Pad left
		if (string.length() > length) {
			string = string.substring(0, length - 1);
		}
		return String.format("%1$" + length + "s", string);

	}

	/**
	 * This function shows how to read the MSR data(credit card) of a portable
	 * printer. The function first puts the printer into MSR read mode, then
	 * asks the user to swipe a credit card The function waits for a response
	 * from the user. The user can cancel MSR mode or have the printer read the
	 * card.
	 * 
	 * @param context
	 *            Activity for displaying messages to the user
	 * @param portName
	 *            Port name to use for communication. This should be
	 *            (TCP:<IPAddress> or BT:<Device pair name>)
	 * @param portSettings
	 *            Should be mini, the port settings mini is used for portable
	 *            printers
	 * @param strPrintArea
	 *            Printable area size, This should be ("2inch (58mm)" or
	 *            "3inch (80mm)")
	 */
	public static boolean PrintSampleReceipt(Context context, String portName,
			String portSettings, String strPrintArea) {
		ArrayList<byte[]> list = new ArrayList<byte[]>();

		if (strPrintArea.equals("2inch (58mm)")) {
			byte[] outputByteBuffer = null;
			list.add(new byte[] { 0x1d, 0x57, (byte) 0x80, 0x31 }); // Page Area
																	// Setting
																	// <GS> <W>
																	// nL nH (nL
																	// = 128, nH
																	// = 1)

			list.add(new byte[] { 0x1b, 0x61, 0x01 }); // Center Justification
														// <ESC> a n (0 Left, 1
														// Center, 2 Right)

			// outputByteBuffer = ("[Print Stored Logo Below]\n\n").getBytes();
			// port.writePort(outputByteBuffer, 0, outputByteBuffer.length);
			//
			// list.add(new byte[]{0x1b, 0x66, 0x00}); //Stored Logo Printing
			// <ESC> f n (n = Store Logo # = 0 or 1 or 2 etc.)

			list.add(("Star Clothing Boutique\n" + "123 Star Road\n"
					+ "City, State 12345\n\n").getBytes());

			list.add(new byte[] { 0x1b, 0x61, 0x00 }); // Left Alignment

			list.add(("Date: MM/DD/YYYY   Time:HH:MM PM\n"
					+ "--------------------------------\n").getBytes());

			list.add(new byte[] { 0x1b, 0x45, 0x01 }); // Set Emphasized
														// Printing ON

			list.add("SALE\n".getBytes());

			list.add(new byte[] { 0x1b, 0x45, 0x00 }); // Set Emphasized
														// Printing OFF (same
														// command as on)

			outputByteBuffer = ("300678566  PLAIN T-SHIRT  10.99\n"
					+ "300692003  BLACK DENIM    29.99\n"
					+ "300651148  BLUE DENIM     29.99\n"
					+ "300642980  STRIPED DRESS  49.99\n"
					+ "300638471  BLACK BOOTS    35.99\n\n"
					+ "Subtotal                 156.95" + "\n"
					+ "Tax                        0.00" + "\n"
					+ "--------------------------------\n" + "Total ")
					.getBytes();
			list.add(outputByteBuffer);

			list.add(new byte[] { 0x1d, 0x21, 0x11 }); // Width and Height
														// Character Expansion
														// <GS> ! n

			list.add("      $156.95\n".getBytes());

			list.add(new byte[] { 0x1d, 0x21, 0x00 }); // Cancel Expansion -
														// Reference Star
														// Portable Printer
														// Programming Manual

			list.add(("--------------------------------\n" + "Charge\n"
					+ "$156.95\n" + "Visa XXXX-XXXX-XXXX-0123\n").getBytes());

			list.add(new byte[] { 0x1d, 0x77, 0x02 }); // for 1D Code39 Barcode
			list.add(new byte[] { 0x1d, 0x68, 0x64 }); // for 1D Code39 Barcode
			list.add(new byte[] { 0x1d, 0x48, 0x01 }); // for 1D Code39 Barcode
			list.add(new byte[] { 0x1d, 0x6b, 0x41, 0x0b, 0x30, 0x31, 0x32,
					0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30 }); // for 1D
																		// Code39
																		// Barcode

			list.add("\n".getBytes());

			list.add(new byte[] { 0x1d, 0x42, 0x01 }); // Specify White-Black
														// Invert

			list.add("Refunds and Exchanges\n".getBytes());

			list.add(new byte[] { 0x1d, 0x42, 0x00 }); // Cancel White-Black
														// Invert

			list.add("Within ".getBytes());

			list.add(new byte[] { 0x1b, 0x2d, 0x01 }); // Specify Underline
														// Printing

			list.add("30 days".getBytes());

			list.add(new byte[] { 0x1b, 0x2d, 0x00 }); // Cancel Underline
														// Printing

			outputByteBuffer = (" with receipt\n" + "And tags attached\n"
					+ "-------------Sign Here----------\n\n\n"
					+ "--------------------------------\n"
					+ "Thank you for buying Star!\n"
					+ "Scan QR code to visit our site!\n").getBytes();
			list.add(outputByteBuffer);

			list.add(new byte[] { 0x1d, 0x5a, 0x02 }); // Cancel Underline
														// Printing

			byte[] qrcodeByteBuffer = new byte[] { 0x1d, 0x5a, 0x02, 0x1b,
					0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00, 0x68, 0x74, 0x74, 0x70,
					0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77, 0x2e, 0x53, 0x74, 0x61,
					0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f, 0x6e, 0x69, 0x63, 0x73,
					0x2e, 0x63, 0x6f, 0x6d };
			list.add(qrcodeByteBuffer); // QR Code (View QR 2D Barcode code for
										// better explanation)

			list.add("\n\n\n".getBytes());

			return sendCommand(context, portName, portSettings, list);
		} else if (strPrintArea.equals("3inch (80mm)")) {
			byte[] outputByteBuffer = null;

			list.add(new byte[] { 0x1d, 0x57, 0x40, 0x32 }); // Page Area
																// Setting <GS>
																// <W> nL nH (nL
																// = 64, nH = 2)

			list.add(new byte[] { 0x1b, 0x61, 0x01 }); // Center Justification
														// <ESC> a n (0 Left, 1
														// Center, 2 Right)

			// outputByteBuffer = ("[Print Stored Logo Below]\n\n").getBytes();
			// port.writePort(outputByteBuffer, 0, outputByteBuffer.length);
			//
			// list.add(new byte[]{0x1b, 0x66, 0x00}); //Stored Logo Printing
			// <ESC> f n (n = Store Logo # = 0 or 1 or 2 etc.)

			list.add(("\nStar Clothing Boutique\n" + "123 Star Road\n"
					+ "City, State 12345\n\n").getBytes());

			list.add(new byte[] { 0x1b, 0x61, 0x00 }); // Left Alignment

			list.add(new byte[] { 0x1b, 0x44, 0x02, 0x10, 0x22, 0x00 }); // Setting
																			// Horizontal
																			// Tab

			list.add("Date: MM/DD/YYYY ".getBytes());

			list.add(new byte[] { 0x09 }); // Left Alignment"

			list.add(("Time: HH:MM PM\n"
					+ "------------------------------------------------ \n")
					.getBytes());

			list.add(new byte[] { 0x1b, 0x45, 0x01 }); // Set Emphasized
														// Printing ON

			list.add("SALE\n".getBytes());

			list.add(new byte[] { 0x1b, 0x45, 0x00 }); // Set Emphasized
														// Printing OFF (same
														// command as on)

			outputByteBuffer = ("300678566    PLAIN T-SHIRT                 10.99\n"
					+ "300692003    BLACK DENIM                   29.99\n"
					+ "300651148    BLUE DENIM                    29.99\n"
					+ "300642980    STRIPED DRESS                 49.99\n"
					+ "300638471    BLACK BOOTS                   35.99\n\n"
					+ "Subtotal                                  156.95\n"
					+ "Tax                                         0.00\n"
					+ "------------------------------------------------ \n"
					+ "Total   ").getBytes();
			list.add(outputByteBuffer);

			outputByteBuffer = ("<br/>This is text<br/>"
					+ "<br/>This is text<br/><br/>"
					+ "<br/>This is text<br/><br/>"
					+ "<br/>This is text<br/><br/>"
					+ "300678566    Break above                 10.99\n"
					+ "300692003    BLACK DENIM                   29.99\n"
					+ "300651148    BLUE DENIM                    29.99\n"
					+ "300642980    STRIPED DRESS                 49.99\n"
					+ "300638471    BLACK BOOTS                   35.99\n\n"
					+ "Subtotal                                  156.95\n"
					+ "Tax                                         0.00\n"
					+ "------------------------------------------------ \n"
					+ "Total   ").getBytes();
			list.add(outputByteBuffer);

			/*
			 * list.add(new byte[] { 0x1d, 0x21, 0x11 }); // Width and Height
			 * Character Expansion <GS> ! n
			 * 
			 * list.add("             $156.95\n".getBytes());
			 * 
			 * list.add(new byte[] { 0x1d, 0x21, 0x00 }); // Cancel Expansion -
			 * Reference Star Portable Printer Programming Manual
			 * 
			 * list.add(("------------------------------------------------ \n" +
			 * "Charge\n" + "$156.95\n" +
			 * "Visa XXXX-XXXX-XXXX-0123\n").getBytes());
			 * 
			 * list.add(new byte[] { 0x1d, 0x77, 0x02 }); // for 1D Code39
			 * Barcode list.add(new byte[] { 0x1d, 0x68, 0x64 }); // for 1D
			 * Code39 Barcode list.add(new byte[] { 0x1d, 0x48, 0x01 }); // for
			 * 1D Code39 Barcode list.add(new byte[] { 0x1d, 0x6b, 0x41, 0x0b,
			 * 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30
			 * }); // for 1D Code39 Barcode
			 * 
			 * list.add("\n".getBytes());
			 * 
			 * list.add(new byte[] { 0x1d, 0x42, 0x01 }); // Specify White-Black
			 * Invert
			 * 
			 * list.add("Refunds and Exchanges\n".getBytes());
			 * 
			 * list.add(new byte[] { 0x1d, 0x42, 0x00 }); // Cancel White-Black
			 * Invert
			 * 
			 * list.add("Within ".getBytes());
			 * 
			 * list.add(new byte[] { 0x1b, 0x2d, 0x01 }); // Specify Underline
			 * Printing
			 * 
			 * list.add("30 days".getBytes());
			 * 
			 * list.add(new byte[] { 0x1b, 0x2d, 0x00 }); // Cancel Underline
			 * Printing
			 * 
			 * outputByteBuffer = (" with receipt\n" + "And tags attached\n" +
			 * "------------- Card Holder's Signature ---------- \n\n\n" +
			 * "------------------------------------------------ \n" +
			 * "Thank you for buying Star!\n" +
			 * "Scan QR code to visit our site!\n").getBytes();
			 * list.add(outputByteBuffer);
			 * 
			 * list.add(new byte[] { 0x1d, 0x5a, 0x02 }); // Cancel Underline
			 * Printing
			 * 
			 * byte[] qrcodeByteBuffer = new byte[] { 0x1d, 0x5a, 0x02, 0x1b,
			 * 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00, 0x68, 0x74, 0x74, 0x70, 0x3a,
			 * 0x2f, 0x2f, 0x77, 0x77, 0x77, 0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d,
			 * 0x69, 0x63, 0x72, 0x6f, 0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f,
			 * 0x6d }; list.add(qrcodeByteBuffer); // QR Code (View QR 2D
			 * Barcode code for better explanation)
			 */
			list.add("\n\n\n\n".getBytes());
		} else if (strPrintArea.equals("4inch (112mm)")) {
			byte[] outputByteBuffer = null;

			list.add(new byte[] { 0x1d, 0x57, 0x40, 0x32 }); // Page Area
																// Setting <GS>
																// <W> nL nH (nL
																// = 64, nH = 2)

			list.add(new byte[] { 0x1b, 0x61, 0x01 }); // Center Justification
														// <ESC> a n (0 Left, 1
														// Center, 2 Right)

			// outputByteBuffer = ("[Print Stored Logo Below]\n\n").getBytes();
			// port.writePort(outputByteBuffer, 0, outputByteBuffer.length);
			//
			// list.add(new byte[]{0x1b, 0x66, 0x00})); //Stored Logo Printing
			// <ESC> f n (n = Store Logo # = 0 or 1 or 2 etc.)

			list.add(("\nStar Clothing Boutique\n" + "123 Star Road\n"
					+ "City, State 12345\n\n").getBytes());

			list.add(new byte[] { 0x1b, 0x61, 0x00 }); // Left Alignment

			list.add(new byte[] { 0x1b, 0x44, 0x02, 0x1b, 0x34, 0x00 }); // Setting
																			// Horizontal
																			// Tab

			list.add("Date: MM/DD/YYYY ".getBytes());

			list.add(new byte[] { 0x09 }); // Left Alignment"

			list.add(("Time: HH:MM PM\n"
					+ "--------------------------------------------------------------------- \n")
					.getBytes());

			list.add(new byte[] { 0x1b, 0x45, 0x01 }); // Set Emphasized
														// Printing ON

			list.add("SALE\n".getBytes());

			list.add(new byte[] { 0x1b, 0x45, 0x00 }); // Set Emphasized
														// Printing OFF (same
														// command as on)

			outputByteBuffer = ("300678566 \u0009  PLAIN T-SHIRT\u0009         10.99\n"
					+ "300692003 \u0009  BLACK DENIM\u0009         29.99\n"
					+ "300651148 \u0009  BLUE DENIM\u0009         29.99\n"
					+ "300642980 \u0009  STRIPED DRESS\u0009         49.99\n"
					+ "300638471 \u0009  BLACK BOOTS\u0009         35.99\n\n"
					+ "Subtotal \u0009\u0009        156.95\n"
					+ "Tax \u0009\u0009          0.00\n"
					+ "--------------------------------------------------------------------- \n"
					+ "Total\u0009").getBytes();
			list.add(outputByteBuffer);

			list.add(new byte[] { 0x1d, 0x21, 0x11 }); // Width and Height
														// Character Expansion
														// <GS> ! n

			list.add("\u0009$156.95\n".getBytes());

			list.add(new byte[] { 0x1d, 0x21, 0x00 }); // Cancel Expansion -
														// Reference Star
														// Portable Printer
														// Programming Manual

			outputByteBuffer = ("--------------------------------------------------------------------- \n"
					+ "Charge\n" + "$156.95\n" + "Visa XXXX-XXXX-XXXX-0123\n")
					.getBytes();
			list.add(outputByteBuffer);

			list.add(new byte[] { 0x1d, 0x77, 0x02 }); // for 1D Code39 Barcode
			list.add(new byte[] { 0x1d, 0x68, 0x64 }); // for 1D Code39 Barcode
			list.add(new byte[] { 0x1d, 0x48, 0x01 }); // for 1D Code39 Barcode
			list.add(new byte[] { 0x1d, 0x6b, 0x41, 0x0b, 0x30, 0x31, 0x32,
					0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30 }); // for 1D
																		// Code39
																		// Barcode

			list.add("\n".getBytes());

			list.add(new byte[] { 0x1d, 0x42, 0x01 }); // Specify White-Black
														// Invert

			list.add("Refunds and Exchanges\n".getBytes());

			list.add(new byte[] { 0x1d, 0x42, 0x00 }); // Cancel White-Black
														// Invert

			list.add("Within ".getBytes());

			list.add(new byte[] { 0x1b, 0x2d, 0x01 }); // Specify Underline
														// Printing

			list.add("30 days".getBytes());

			list.add(new byte[] { 0x1b, 0x2d, 0x00 }); // Cancel Underline
														// Printing

			outputByteBuffer = (" with receipt\n"
					+ "And tags attached\n"
					+ "----------------------- Card Holder's Signature --------------------- \n\n\n"
					+ "--------------------------------------------------------------------- \n"
					+ "Thank you for buying Star!\n"
					+ "Scan QR code to visit our site!\n").getBytes();
			list.add(outputByteBuffer);

			list.add(new byte[] { 0x1d, 0x5a, 0x02 }); // Cancel Underline
														// Printing

			byte[] qrcodeByteBuffer = new byte[] { 0x1d, 0x5a, 0x02, 0x1b,
					0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00, 0x68, 0x74, 0x74, 0x70,
					0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77, 0x2e, 0x53, 0x74, 0x61,
					0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f, 0x6e, 0x69, 0x63, 0x73,
					0x2e, 0x63, 0x6f, 0x6d };
			list.add(qrcodeByteBuffer); // QR Code (View QR 2D Barcode code for
										// better explanation)

			list.add("\n\n\n\n".getBytes());
		}

		return sendCommand(context, portName, portSettings, list);
	}

	/**
	 * This function shows how to get the status of a printer
	 * 
	 * @param context
	 *            Activity for displaying messages to the user
	 * @param portName
	 *            Port name to use for communication. This should be
	 *            (TCP:<IPAddress> or BT:<DeviceName> for bluetooth)
	 * @param portSettings
	 *            Should be mini, the port settings mini is used for portable
	 *            printers
	 */
	// portSettings = "mini";
	// String portName = BT:<DeviceName>;
	// context = this
	public static void CheckStatus(Context context, String portName,
			String portSettings) {
		StarIOPort port = null;
		try {
			/*
			 * using StarIOPort3.1.jar (support USB Port) Android OS Version:
			 * upper 2.2
			 */
			port = StarIOPort.getPort(portName, portSettings, 10000, context);
			/*
			 * using StarIOPort.jar Android OS Version: under 2.1 port =
			 * StarIOPort.getPort(portName, portSettings, 10000);
			 */

			// A sleep is used to get time for the socket to completely open
			try {
				Thread.sleep(500);
			} catch (InterruptedException e) {
			}

			StarPrinterStatus status = port.retreiveStatus();

			if (status.offline == false) {
				Builder dialog = new AlertDialog.Builder(context);
				dialog.setNegativeButton("Ok", null);
				AlertDialog alert = dialog.create();
				alert.setTitle("Printer");
				alert.setMessage("Printer is Online");
				alert.setCancelable(false);
				alert.show();
			} else {
				String message = "Printer is offline";
				if (status.receiptPaperEmpty == true) {
					message += "\nPaper is Empty";
				}
				if (status.coverOpen == true) {
					message += "\nCover is Open";
				}
				Builder dialog = new AlertDialog.Builder(context);
				dialog.setNegativeButton("Ok", null);
				AlertDialog alert = dialog.create();
				alert.setTitle("Printer");
				alert.setMessage(message);
				alert.setCancelable(false);
				alert.show();
			}
		} catch (StarIOPortException e) {
			Builder dialog = new AlertDialog.Builder(context);
			dialog.setNegativeButton("Ok", null);
			AlertDialog alert = dialog.create();
			alert.setTitle("Failure");
			alert.setMessage("Failed to connect to printer");
			alert.setCancelable(false);
			alert.show();
		} finally {
			if (port != null) {
				try {
					StarIOPort.releasePort(port);
				} catch (StarIOPortException e) {
				}
			}
		}
	}

	/**
	 * This function shows how to get the firmware information of a printer
	 * 
	 * @param context
	 *            Activity for displaying messages to the user
	 * @param portName
	 *            Port name to use for communication. This should be
	 *            (TCP:<IPAddress> or BT:<DeviceName> for bluetooth)
	 * @param portSettings
	 *            Should be mini, the port settings mini is used for portable
	 *            printers
	 */
	public static void CheckFirmwareVersion(Context context, String portName,
			String portSettings) {
		StarIOPort port = null;
		try {
			/*
			 * using StarIOPort3.1.jar (support USB Port) Android OS Version:
			 * upper 2.2
			 */
			port = StarIOPort.getPort(portName, portSettings, 10000, context);
			/*
			 * using StarIOPort.jar Android OS Version: under 2.1 port =
			 * StarIOPort.getPort(portName, portSettings, 10000);
			 */

			// A sleep is used to get time for the socket to completely open
			try {
				Thread.sleep(500);
			} catch (InterruptedException e) {
			}

			Map<String, String> firmware = port.getFirmwareInformation();

			String modelName = firmware.get("ModelName");
			String firmwareVersion = firmware.get("FirmwareVersion");

			String message = "Model Name:" + modelName;
			message += "\nFirmware Version:" + firmwareVersion;

			Builder dialog = new AlertDialog.Builder(context);
			dialog.setNegativeButton("Ok", null);
			AlertDialog alert = dialog.create();
			alert.setTitle("Firmware Information");
			alert.setMessage(message);
			alert.setCancelable(false);
			alert.show();

		} catch (StarIOPortException e) {
			Builder dialog = new AlertDialog.Builder(context);
			dialog.setNegativeButton("Ok", null);
			AlertDialog alert = dialog.create();
			alert.setTitle("Failure");
			alert.setMessage("Failed to connect to printer");
			alert.setCancelable(false);
			alert.show();
		} finally {
			if (port != null) {
				try {
					StarIOPort.releasePort(port);
				} catch (StarIOPortException e) {
				}
			}
		}
	}

	/*
	 * private static void checkPrinterSendToComplete(StarIOPort port) throws
	 * StarIOPortException { int timeout = 20000; long timeCount = 0; int
	 * readSize = 0; byte[] statusCommand = new byte[] { 0x1b, 0x76 }; byte[]
	 * statusReadByte = new byte[] { 0x00 }; try { port.writePort(statusCommand,
	 * 0, statusCommand.length); StarPrinterStatus status =
	 * port.retreiveStatus(); if (status.coverOpen) { throw new
	 * StarIOPortException("printer is cover open"); } if
	 * (status.receiptPaperEmpty) { throw new
	 * StarIOPortException("paper is empty"); } if (status.offline) { throw new
	 * StarIOPortException("printer is offline"); } long timeStart =
	 * System.currentTimeMillis(); while (timeCount < timeout) { readSize =
	 * port.readPort(statusReadByte, 0, 1); if (readSize == 1) { break; }
	 * timeCount = System.currentTimeMillis() - timeStart; } } catch
	 * (StarIOPortException e) { try { try { Thread.sleep(500); }
	 * catch(InterruptedException ie) {} StarPrinterStatus status =
	 * port.retreiveStatus(); if (status.coverOpen) { throw new
	 * StarIOPortException("printer is cover open"); } if
	 * (status.receiptPaperEmpty) { throw new
	 * StarIOPortException("paper is empty"); } if (status.offline) { throw new
	 * StarIOPortException("printer is offline"); } long timeStart =
	 * System.currentTimeMillis(); while (timeCount < timeout) { readSize =
	 * port.readPort(statusReadByte, 0, 1); if (readSize == 1) { break; }
	 * timeCount = System.currentTimeMillis() - timeStart; } } catch
	 * (StarIOPortException ex) { throw new
	 * StarIOPortException(ex.getMessage()); } } }
	 */

	private static boolean sendCommand(Context context, String portName,
			String portSettings, ArrayList<byte[]> byteList) {
		boolean result = true;
		StarIOPort port = null;
		try {
			/*
			 * using StarIOPort3.1.jar (support USB Port) Android OS Version:
			 * upper 2.2
			 */
			port = StarIOPort.getPort(portName, portSettings, 20000, context);
			/*
			 * using StarIOPort.jar Android OS Version: under 2.1 port =
			 * StarIOPort.getPort(portName, portSettings, 10000);
			 */
			try {
				Thread.sleep(500);
			} catch (InterruptedException e) {
			}

			/*
			 * Portable Printer Firmware Version 2.4 later, SM-S220i(Firmware
			 * Version 2.0 later) Using Begin / End Checked Block method for
			 * preventing "data detective". When sending large amounts of raster
			 * data, use Begin / End Checked Block method and adjust the value
			 * in the timeout in the "StarIOPort.getPort" in order to prevent
			 * "timeout" of the "endCheckedBlock method" while a printing. If
			 * receipt print is success but timeout error occurs(Show message
			 * which is
			 * "There was no response of the printer within the timeout period."
			 * ), need to change value of timeout more longer in
			 * "StarIOPort.getPort" method. (e.g.) 10000 -> 30000When use
			 * "Begin / End Checked Block Sample Code", do comment out
			 * "query commands Sample code".
			 */

			/* Start of Begin / End Checked Block Sample code */
			StarPrinterStatus status = port.beginCheckedBlock();

			if (true == status.offline) {
				throw new StarIOPortException("A printer is offline");
			}

			byte[] commandToSendToPrinter = convertFromListByteArrayTobyteArray(byteList);
			port.writePort(commandToSendToPrinter, 0,
					commandToSendToPrinter.length);

			port.setEndCheckedBlockTimeoutMillis(30000);// Change the timeout
														// time of
														// endCheckedBlock
														// method.
			status = port.endCheckedBlock();

			if (true == status.coverOpen) {
				throw new StarIOPortException("Printer cover is open");
			} else if (true == status.receiptPaperEmpty) {
				throw new StarIOPortException("Receipt paper is empty");
			} else if (true == status.offline) {
				throw new StarIOPortException("Printer is offline");
			}
			/* End of Begin / End Checked Block Sample code */

			/*
			 * Portable Printer Firmware Version 2.3 earlier Using query
			 * commands for preventing "data detective". When sending large
			 * amounts of raster data, send query commands after writePort data
			 * for confirming the end of printing and adjust the value in the
			 * timeout in the "checkPrinterSendToComplete" method in order to
			 * prevent "timeout" of the "sending query commands" while a
			 * printing. If receipt print is success but timeout error
			 * occurs(Show message which is
			 * "There was no response of the printer within the timeout period."
			 * ), need to change value of timeout more longer in
			 * "checkPrinterSendToComplete" method. (e.g.) 10000 -> 30000When
			 * use "query commands Sample code", do comment out
			 * "Begin / End Checked Block Sample Code".
			 */

			/* Start of query commands Sample code */
			// byte[] commandToSendToPrinter =
			// convertFromListByteArrayTobyteArray(byteList);
			// port.writePort(commandToSendToPrinter, 0,
			// commandToSendToPrinter.length);
			//
			// checkPrinterSendToComplete(port);
			/* End of query commands Sample code */
		} catch (StarIOPortException e) {
			result = false;
			Builder dialog = new AlertDialog.Builder(context);
			dialog.setNegativeButton("Ok", null);
			AlertDialog alert = dialog.create();
			alert.setTitle("Failure");
			alert.setMessage(e.getMessage());
			alert.setCancelable(false);
			alert.show();
		} finally {
			if (port != null) {
				try {
					StarIOPort.releasePort(port);
				} catch (StarIOPortException e) {
				}
			}
		}

		return result;
	}

	private static byte[] convertFromListByteArrayTobyteArray(
			List<byte[]> ByteArray) {
		int dataLength = 0;
		for (int i = 0; i < ByteArray.size(); i++) {
			dataLength += ByteArray.get(i).length;
		}

		int distPosition = 0;
		byte[] byteArray = new byte[dataLength];
		for (int i = 0; i < ByteArray.size(); i++) {
			System.arraycopy(ByteArray.get(i), 0, byteArray, distPosition,
					ByteArray.get(i).length);
			distPosition += ByteArray.get(i).length;
		}

		return byteArray;
	}

	/**
	 * Get the device's Universally Unique Identifier (UUID).
	 * 
	 * @return
	 */
	public String getUuid() {
		String uuid = Settings.Secure.getString(this.cordova.getActivity()
				.getContentResolver(),
				android.provider.Settings.Secure.ANDROID_ID);
		return uuid;
	}

	public String getModel() {
		String model = android.os.Build.MODEL;
		return model;
	}

	public String getProductName() {
		String productname = android.os.Build.PRODUCT;
		return productname;
	}

	public String getManufacturer() {
		String manufacturer = android.os.Build.MANUFACTURER;
		return manufacturer;
	}

	/**
	 * Get the OS version.
	 * 
	 * @return
	 */
	public String getOSVersion() {
		String osversion = android.os.Build.VERSION.RELEASE;
		return osversion;
	}

	public String getSDKVersion() {
		@SuppressWarnings("deprecation")
		String sdkversion = android.os.Build.VERSION.SDK;
		return sdkversion;
	}

	public String getTimeZoneID() {
		TimeZone tz = TimeZone.getDefault();
		return (tz.getID());
	}

}