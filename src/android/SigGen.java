package com.star.printer;

import java.io.IOException; 
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
 
 
    /** 
     * A point along a line within a signature. 
     */ 
    public static class Point { 
 
        private int x; 
        private int y; 
 
        public Point(float x, float y) { 
            this.x = Math.round(x); 
            this.y = Math.round(y); 
        } 
    } 
  
    /** 
     * Extract the signature lines and points from the JSON encoding. 
     * 
     * @param  jsonEncoding  the JSON representation of the signature 
     * @return  the retrieved lines and points 
     */ 
    public static List<List<Point>> ExtractSignature(String jsonEncoding) { 
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

    /** 
     * Redraw the signature from its lines definition. 
     * 
     * @param  lines  the individual lines in the signature 
     * @return  the corresponding signature image 
     * @throws  IOException  if a problem generating the signature 
     */ 
    public static Bitmap redrawSignatureBMP(String jsonEncoding) throws IOException {     
    	Bitmap bitmap = Bitmap.createBitmap(576, 300, Config.ARGB_8888);
    	List<List<Point>> lines = ExtractSignature(jsonEncoding);
    
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
