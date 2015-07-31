package com.star.printer;


import java.io.ByteArrayOutputStream; 
import java.io.IOException; 
import java.io.OutputStream; 
import java.util.ArrayList; 
import java.util.List; 
import java.util.regex.Matcher; 
import java.util.regex.Pattern; 
 

import android.graphics.Color;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Bitmap.Config;
 
public class SigGen { 
 
    private static final String IMAGE_FORMAT = "png"; 
    private static final int SIGNATURE_HEIGHT = 200; 
    private static final int SIGNATURE_WIDTH = 400; 
 
    /** 
     * A point along a line within a signature. 
     */ 
    private static class Point { 
 
        private int x; 
        private int y; 
 
        public Point(float x, float y) { 
            this.x = Math.round(x); 
            this.y = Math.round(y); 
        } 
    } 
 
//    /** 
//     * Extract a signature from its JSON encoding and redraw it as an image. 
//     * 
//     * @param  jsonEncoding  the JSON representation of the signature 
//     * @param  output        the destination stream for the image 
//     * @throws  IOException  if a problem writing the signature 
//     */ 
//    public static void generateSignature(String jsonEncoding, OutputStream output) 
//            throws IOException { 
//        output.write(redrawSignature(extractSignature(jsonEncoding))); 
//        output.close(); 
//    } 
 
    /** 
     * Extract the signature lines and points from the JSON encoding. 
     * 
     * @param  jsonEncoding  the JSON representation of the signature 
     * @return  the retrieved lines and points 
     */ 
    private static List<List<Point>> extractSignature(String jsonEncoding) { 
        List<List<Point>> lines = new ArrayList<List<Point>>(); 
        Matcher lineMatcher = 
                Pattern.compile("(\\[(?:,?\\[-?[\\d\\.]+,-?[\\d\\.]+\\])+\\])"). 
                matcher(jsonEncoding); 
        while (lineMatcher.find()) { 
            Matcher pointMatcher = 
                    Pattern.compile("\\[(-?[\\d\\.]+),(-?[\\d\\.]+)\\]"). 
                    matcher(lineMatcher.group(1)); 
            List<Point> line = new ArrayList<Point>(); 
            lines.add(line); 
            while (pointMatcher.find()) { 
                line.add(new Point(Float.parseFloat(pointMatcher.group(1)), 
                        Float.parseFloat(pointMatcher.group(2)))); 
            } 
        } 
        return lines; 
    } 

    private static float maxWidth(String jsonEncoding) { 
        float mWidth = (float)0;
        Matcher lineMatcher = 
                Pattern.compile("(\\[(?:,?\\[-?[\\d\\.]+,-?[\\d\\.]+\\])+\\])"). 
                matcher(jsonEncoding); 
        while (lineMatcher.find()) { 
            Matcher pointMatcher = 
                    Pattern.compile("\\[(-?[\\d\\.]+),(-?[\\d\\.]+)\\]"). 
                    matcher(lineMatcher.group(1)); 
            while (pointMatcher.find()) { 
            	if(Float.parseFloat(pointMatcher.group(1)) > mWidth){
            		mWidth = Float.parseFloat(pointMatcher.group(1));
            			}
            } 
        } 
        return mWidth; 
    } 
//    /** 
//     * Redraw the signature from its lines definition. 
//     * 
//     * @param  lines  the individual lines in the signature 
//     * @return  the corresponding signature image 
//     * @throws  IOException  if a problem generating the signature 
//     */ 
//    private static byte[] redrawSignature(List<List<Point>> lines) throws IOException { 
//        BufferedImage signature = new BufferedImage( 
//                SIGNATURE_WIDTH, SIGNATURE_HEIGHT, BufferedImage.TYPE_BYTE_GRAY); 
//        Graphics2D g = (Graphics2D)signature.getGraphics(); 
//        g.setColor(Color.WHITE); 
//        g.fillRect(0, 0, signature.getWidth(), signature.getHeight()); 
//        g.setColor(Color.BLACK); 
//        g.setStroke(new BasicStroke(2, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)); 
//        g.setRenderingHint( 
//                RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON); 
//        Point lastPoint = null; 
//        for (List<Point> line : lines) { 
//            for (Point point : line) { 
//                if (lastPoint != null) { 
//                    g.drawLine(lastPoint.x, lastPoint.y, point.x, point.y); 
//                } 
//                lastPoint = point; 
//            } 
//            lastPoint = null; 
//        } 
//        ByteArrayOutputStream output = new ByteArrayOutputStream(); 
//        ImageIO.write(signature, IMAGE_FORMAT, output); 
//        return output.toByteArray(); 
//    } 
    /** 
     * Redraw the signature from its lines definition. 
     * 
     * @param  lines  the individual lines in the signature 
     * @return  the corresponding signature image 
     * @throws  IOException  if a problem generating the signature 
     */ 
    public static Bitmap redrawSignatureBMP(String jsonEncoding) throws IOException {     
    	Bitmap bitmap = Bitmap.createBitmap(576, 300, Config.ARGB_8888);
    	List<List<Point>> lines = extractSignature(jsonEncoding);
    
    	float _maxWidth = maxWidth(jsonEncoding);
    	_maxWidth = bitmap.getWidth() - _maxWidth;
    	_maxWidth = _maxWidth / 2;
    
    
    Canvas canvas = new Canvas(bitmap);
		    
		canvas.drawRGB(255, 255, 255);
		Paint paint = new Paint();
		//border's properties
		paint.setColor(Color.BLACK);
		paint.setStrokeWidth(3);        
		paint.setStyle(Paint.Style.STROKE); 
		
	      Point lastPoint = null; 
	      for (List<Point> line : lines) { 
	          for (Point point : line) { 
	              if (lastPoint != null) { 
	            	  canvas.drawLine(lastPoint.x + _maxWidth, lastPoint.y, point.x + _maxWidth, point.y,paint); 
	              } 
	              lastPoint = point; 
	          } 
	          lastPoint = null; 
	      } 

	      canvas.drawLine((float)0, (float)0, (float)576, (float)0, paint); 
	      canvas.drawLine((float)576, (float)0, (float)576, (float)300, paint);
	      canvas.drawLine((float)576, (float)300, (float)0, (float)300, paint);
	      canvas.drawLine((float)0, (float)300, (float)0, (float)0, paint);
		
		canvas.drawBitmap(bitmap, 0, 0, paint);
		
		return bitmap;
    } 
}
