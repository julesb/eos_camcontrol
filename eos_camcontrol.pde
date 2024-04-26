import java.util.HashSet;
import java.awt.Robot;
import java.awt.AWTException;
import java.awt.Point;
import com.jogamp.nativewindow.util.PointImmutable;
import com.jogamp.newt.opengl.GLWindow;
import com.jogamp.newt.event.KeyEvent;
import oscP5.*;
import netP5.*;

final float PI_2 = PI / 2;
HashSet<Character> keysPressed = new HashSet<Character>();
Robot robot;
Camera cam;
OscP5 oscP5;
NetAddress remoteAddr;
PGraphics viewport;

Boolean mouseLocked = false;
Boolean becameLocked = false;
color textBGColor = color(0, 0, 0, 64);
int TEXT_SIZE_NORMAL = 20 * displayDensity();

PVector posPrev, lookatPrev;
PVector originIndicator;
Boolean isOriginBehindCamera = false;

void setup() {
  size(720, 720, P3D);
  textSize(TEXT_SIZE_NORMAL);
  oscP5 = new OscP5(this, 9999);
  remoteAddr = new NetAddress("192.168.1.102", 12000);
  cam = new Camera(0, 5, 10);
  posPrev = new PVector(0,0,0);
  lookatPrev = new PVector(0,0,0);
  hint(DISABLE_DEPTH_MASK);
  resizeViewport();
  imageMode(CENTER);
  originIndicator = new PVector(0,0);
  try {
    robot = new Robot();
  }
  catch (AWTException e) {
    e.printStackTrace();
  }

}

void draw() {
  background(0);
  cam.update(keysPressed);
  checkSendOsc();

  // viewport
  renderViewport(viewport);
  image(viewport, width/2, height/2);
  
  // window border
  noFill();
  stroke(32);
  strokeWeight(1);
  rect(0, 0, width, height);
  
  // info panel
  drawInfo(20, 20, 300, 330);
  
  // horizon
  drawHorizon();

  if (originIndicator != null) {
  // if (originIndicator != null && !isOriginBehindCamera) {
    noStroke();
    fill(0,255,0);
    // float yoff = (height - viewport.height) / 2;
    circle(originIndicator.x, originIndicator.y, 8);
    float len = 20;
    PVector end = PVector.sub(new PVector(width/2,height/2), originIndicator);
    end = end.normalize();
    end = end.mult(len);
    end = PVector.add(end, originIndicator);
    strokeWeight(4);
    line(end.x, end.y, originIndicator.x, originIndicator.y);

  }

  // mouselook
  if (mouseLocked && focused) {
    centerMouse();
  }
}


void renderViewport(PGraphics pg) {
  pg.beginDraw(); 
    pg.hint(DISABLE_DEPTH_MASK);
    pg.background(32);

    pg.perspective(radians(cam.fov), cam.aspect,
                   cam.near_clip, cam.far_clip);
    pg.camera(cam.pos.x, cam.pos.y, cam.pos.z,
              cam.lookAt.x, cam.lookAt.y, cam.lookAt.z,
              cam.up.x, cam.up.y, cam.up.z);
    pg.fill(255,0,0, 32);
    pg.stroke(255);
    pg.strokeWeight(1);
    pg.box(2);
    drawAxes(pg);
    getOriginIndicator(pg);
  pg.endDraw();
}


void drawAxes(PGraphics pg) {
  int len = 1000;
  int len2 = 1;
  color grey = color(128,128,128);
  pg.strokeWeight(1);

  // X
  pg.stroke(255,0,0);
  pg.line(0, 0, 0, len, 0, 0);
  pg.stroke(grey);
  pg.line(0, 0, 0, -len, 0, 0);
  // Y
  pg.stroke(0,255,0);
  pg.line(0, 0, 0, 0, len, 0);
  pg.stroke(grey);
  pg.line(0, 0, 0, 0, -len, 0);
  // Z
  pg.stroke(0,0,255);
  pg.line(0, 0, 0, 0, 0, len);
  pg.stroke(grey);
  pg.line(0, 0, 0, 0, 0, -len);
  
  // pg.strokeWeight(4);
  // // X
  // pg.stroke(255,0,0);
  // pg.line(0, 0, 0, len2, 0, 0);
  // // Y
  // pg.stroke(0,255,0);
  // pg.line(0, 0, 0, 0, len2, 0);
  // // Z
  // pg.stroke(0,0,255);
  // pg.line(0, 0, 0, 0, 0, len2);
}


void drawHorizon() {
  float vpy = (height-viewport.height) / 2;
  float horizonY = cam.pos.y + map(cam.alt, -radians(cam.fov)/2, radians(cam.fov)/2, vpy, vpy+viewport.height);
  // float horizonY = cam.pos.y + map(cam.alt, -radians(cam.fov)/2, radians(cam.fov)/2, 0, height);
  noFill();
  stroke(255, 0, 255);
  strokeWeight(1);
  line(0, horizonY, width, horizonY);
}


void drawAspect() {
  float windowAr = (float)width / height;
  float w = width;
  float h = height / cam.aspect*windowAr;
  float x1, y1;
  x1 = 0;
  y1 = height/2 - h/2;
  
  fill(0, 0, 0, 220);
  noStroke();
  rect(0, 0, width, y1);
  rect(0, y1+h, width, (height-h)/2);
  noFill();
  stroke(255,0,0);
  rect(x1, y1, w, h);
}


// void getOriginIndicator(PGraphics pg) {
//   // Get the 2D screen position of the origin direction indicator.
//   // this is approximate. better to get the point where
//   // the line from screencenter to indicator position
//   // intersects the viewport edge
//   float vpx1 = (width - pg.width) / 2;
//   float vpx2 = vpx1 + pg.width;
//   float vpy1 = (height - pg.height) / 2;
//   float vpy2 = vpy1 + pg.height;
//   float x = pg.screenX(0,0,0) + vpx1;
//   float y = pg.screenY(0,0,0) + vpy1;
//   x = max(vpx1, min(vpx2, x));
//   y = max(vpy1, min(vpy2, y));
//   originIndicator.x = x;
//   originIndicator.y = y;
// }


void getOriginIndicator(PGraphics pg) {
  // Define viewport boundaries
  float vpx1 = (width - pg.width) / 2;
  float vpx2 = vpx1 + pg.width;
  float vpy1 = (height - pg.height) / 2;
  float vpy2 = vpy1 + pg.height;
  

  // Screen center
  PVector screenCenter = new PVector(
    width / 2,
    height / 2
  );
  
  // Project origin (0, 0, 0) in world space to screen space
  PVector originScreen = new PVector(
    pg.screenX(0, 0, 0) + vpx1,
    pg.screenY(0, 0, 0) + vpy1
  );
  
  Boolean inViewport = (originScreen.x >= vpx1
                     && originScreen.x < vpx2
                     && originScreen.y >= vpy1
                     && originScreen.y < vpy2);

  // if (!inViewport) {
  // if (isOriginBehindCamera) {
  //   if ((cam.pos.y < 0 && cam.alt < 0)
  //   || (cam.pos.y > 0 && cam.alt > 0)) {
  //     originScreen = PVector.add(screenCenter, PVector.mult(PVector.sub(originScreen, screenCenter), -1));
  //   //   
  //   //   originScreen = PVector.add(screenCenter, PVector.mult(PVector.sub(originScreen, screenCenter), -1));
  //   //   // originScreen.x *= -1;
  //   //   // originScreen.y *= -1;
  //   // }
  //   // else if (cam.pos.y > 0 && cam.alt < 0) {
  //   //   originScreen = PVector.add(screenCenter, PVector.mult(PVector.sub(originScreen, screenCenter), -1));
  //   //   // originScreen.x *= -1;
  //   //   // originScreen.y *= -1;
  //   }
  // }
  
  // originScreen.x += vpx1;
  // originScreen.y += vpy1;


  
  if (originScreen.x >= vpx1 && originScreen.x < vpx2
  && originScreen.y >= vpy1 && originScreen.y < vpy2) {
    // origin is inside the viewport
    originIndicator.x = originScreen.x;
    originIndicator.y = originScreen.y;    
  }
  else {
    // println(originScreen.toString());
    // origin is outside the viewport, find intersection
    // top vp edge
    PVector intersect1 = findIntersection2D(
      new PVector(vpx1, vpy1), new PVector(vpx2, vpy1),
      screenCenter, originScreen);
    // bottom vp edge
    PVector intersect2 = findIntersection2D(
      new PVector(vpx1, vpy2), new PVector(vpx2, vpy2),
      screenCenter, originScreen);
    // left vp edge
    PVector intersect3 = findIntersection2D(
      new PVector(vpx1, vpy1), new PVector(vpx1, vpy2),
      screenCenter, originScreen);
    // right vp edge
    PVector intersect4 = findIntersection2D(
      new PVector(vpx2, vpy1), new PVector(vpx2, vpy2),
      screenCenter, originScreen);

    if (intersect1 != null) {
      originIndicator.x = intersect1.x;
      originIndicator.y = intersect1.y;
    }
    else if (intersect2 != null) {
      originIndicator.x = intersect2.x;
      originIndicator.y = intersect2.y;
    }
    else if (intersect3 != null) {
      originIndicator.x = intersect3.x;
      originIndicator.y = intersect3.y;
    }
    else if (intersect4 != null) {
      originIndicator.x = intersect4.x;
      originIndicator.y = intersect4.y;
    }
    else {
      println("SHOULDNT HAPPEN: origin offscreen and no intersection");
    }
  }
}



void drawInfo(float x, float y, float w, float h) {
  float margin = 12;
  float textOriginX = x+ margin;
  float textOriginY = y+ margin + TEXT_SIZE_NORMAL/2;
  float labelX = textOriginX;
  float valueX = labelX + w/3;
  float lineSpace = TEXT_SIZE_NORMAL + 10;
  int lineCount = 0;
  float textOffsetY = 0; // = textOriginY + lineSpace*lineCount;

  noStroke();
  fill(textBGColor);
  rect (x, y, w, h, 16);
  
  fill(255);
  // Camera Pos
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String posValue = String.format("[% .2f, % .2f, % .2f]",
                                      cam.pos.x, cam.pos.y, cam.pos.z);
  text("Viewpoint", labelX, textOffsetY);
  text(posValue, valueX, textOffsetY);

  // Camera Lookat
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String lookatValue = String.format("[% .2f, % .2f, % .2f]",
                                     cam.lookAt.x, cam.lookAt.y, cam.lookAt.z);
  text("Look at", labelX, textOffsetY);
  text(lookatValue, valueX, textOffsetY);
  
  // VPN
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String vpnValue = String.format("[% .2f, % .2f, % .2f]",
                                  cam.vpn.x, cam.vpn.y, cam.vpn.z);
  text("VPN", labelX, textOffsetY);
  text(vpnValue, valueX, textOffsetY);
  
  // Velocity
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String velValue = String.format("[% .2f, % .2f, % .2f]",
                                  cam.vel.x, cam.vel.y, cam.vel.z);
  text("Velocity", labelX, textOffsetY);
  text(velValue, valueX, textOffsetY);

  textOffsetY = textOriginY + lineSpace*lineCount++;
  String azValue = String.format("%.2f", degrees(cam.az));
  text("Azimuth", labelX, textOffsetY);
  text(azValue, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String altValue = String.format("%.2f", degrees(cam.alt));
  text("Altitude", labelX, textOffsetY);
  text(altValue, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String fovValue = String.format("%.2f", cam.fov);
  text("FOV", labelX, textOffsetY);
  text(fovValue, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String arValue = String.format("%.2f", cam.aspect);
  text("Aspect", labelX, textOffsetY);
  text(arValue, valueX, textOffsetY);

  textOffsetY = textOriginY + lineSpace*lineCount++;
  String nearVal = String.format("%.2f", cam.near_clip);
  text("Near clip", labelX, textOffsetY);
  text(nearVal, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String farVal = String.format("%.2f", cam.far_clip);
  text("Far clip", labelX, textOffsetY);
  text(farVal, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String modeVal = (cam.mode == Camera.FLY)? "Fly": "Orbit";
  text("Mode", labelX, textOffsetY);
  text(modeVal, valueX, textOffsetY);
}



void keyPressed() {
  keysPressed.add(key);
}

void keyReleased() {
  keysPressed.remove(key);
}


void keyTyped() {
  switch(key) {
    case ' ':
      setMouseLock(!mouseLocked);
      break;
    case '0':
      cam.pos = new PVector(0,0,0);
      cam.orbitVel = 0.0;
      break;
    case '`':
      cam.mode = 1 - cam.mode; // assumes two modes
      break;
    // case '=':
    //   cam.fov += 0.1;
    //   break;
    // case '-':
    //   cam.fov -= 0.1;
    //   break;
      
  }
}

void centerMouse() {
   PointImmutable locationImmutable = ((GLWindow)surface.getNative()).getLocationOnScreen(null);
  Point location = new Point(locationImmutable.getX(), locationImmutable.getY());

  int centerX = location.x + width / 2;
  int centerY = location.y + height / 2;
  robot.mouseMove(centerX, centerY);
}

void setMouseLock(Boolean isLocked) {
  mouseLocked = isLocked;
  if (mouseLocked) {
    becameLocked = true;
    noCursor();
  }
  else {
    cursor();
  }
}

class Camera {
  public static final int FLY = 0;
  public static final int ORBIT = 1;
  PVector pos, lookAt, vel, vpn, up;
  float near_clip, far_clip;
  float az, alt, azVel, altVel;
  float dampR, dampM, fov, accel_force,
        breaking_force, zRot, aspect ;

  int mode = FLY;
  float orbitAngle = 0.0;
  float orbitVel = 0.1;
  float orbitRadius = 5.0;
  float orbitAlt = 0.0;

  Camera(float x, float y, float z) {
    pos = new PVector(x, y, z);
    lookAt = new PVector(0, 0, 0);
    near_clip = 0.5;
    far_clip = 100;
    vel = new PVector(0, 0, 0);
    vpn = new PVector(0, 0, -1);
    up = new PVector(0, -1, 0);
    az = 270;
    alt = 0;
    azVel = 0;
    altVel = 0;
    dampR = 0.0005;
    dampM = 0.002;
    fov = 60; // PI / 3;
    aspect = 16.0 / 9.0; // float(width)/height;
    accel_force = 20.0;
    breaking_force = 10.0; 
    zRot = 0;
  }

  void update(HashSet<Character> keys) {
     // float accel_force = 20;
    float dt = 1.0 / frameRate;
    if (keys.contains('w')) {
      if (mode == FLY) {
        PVector forward_force = PVector.mult(vpn, dt*accel_force);
        vel = vel.sub(forward_force);
      }
      else if (mode == ORBIT) {
        cam.orbitRadius -= 0.1;
      }
    }
    if (keys.contains('s')) {
      if (mode == FLY) {
        PVector backward_force = PVector.mult(vpn, dt*-accel_force);
        vel = vel.sub(backward_force);
      }
      else if (mode == ORBIT) {
        cam.orbitRadius += 0.1;
      }
    }
    if (keys.contains('a')) {
      if (mode == FLY) {
        PVector strafe = PVector.mult(vpn.cross(up).normalize(), dt*accel_force);
        vel.add(strafe);
      }
      else if (mode == ORBIT) {
        cam.orbitVel += 0.1;
      }
    }
    if (keys.contains('d')) {
      if (mode == FLY) {
        PVector strafe = PVector.mult(vpn.cross(up).normalize(), dt*-accel_force);
        vel.add(strafe);
      }
      else if (mode == ORBIT) {
        cam.orbitVel -= 0.1;
      }
    }

    if (keys.contains('e')) {
      vel.add(PVector.mult(up, dt*accel_force));
    }
    if (keys.contains('c')) {
      vel.sub(PVector.mult(up, dt*accel_force));
    }
    if (keys.contains('x')) {
      PVector brakingForce = PVector.mult(vel, breaking_force * dt * -1);
      vel.add(brakingForce);
    }

    if (keys.contains('-')) {
      cam.fov -= 0.1;
      sendOscFloat("/camcontrol/cam/fov", cam.fov);
    }
    if (keys.contains('=')) {
      cam.fov += 0.1;
      sendOscFloat("/camcontrol/cam/fov", cam.fov);
    }
    
    if (keys.contains('n')) {
      cam.near_clip -= 0.01;
      sendOscFloat("/camcontrol/cam/near", cam.near_clip);
    }
    if (keys.contains('N')) {
      cam.near_clip += 0.01;
      sendOscFloat("/camcontrol/cam/near", cam.near_clip);
    }
    if (keys.contains('f')) {
      cam.far_clip -= 0.1;
      sendOscFloat("/camcontrol/cam/far", cam.far_clip);
    }
    if (keys.contains('F')) {
      cam.far_clip += 0.1;
      sendOscFloat("/camcontrol/cam/far", cam.far_clip);
    }
    if (keys.contains('[')) {
      cam.aspect -= 0.01;
      sendOscFloat("/camcontrol/cam/aspect", cam.aspect);
      resizeViewport();
    }
    if (keys.contains(']')) {
      cam.aspect += 0.01;
      sendOscFloat("/camcontrol/cam/aspect", cam.aspect);
      resizeViewport();
    }

    if (mode == FLY) {
      if (focused) {
        updateFly(dt);
      }
    }
    else if (mode == ORBIT) {
      updateFly(dt);
      updateOrbit(dt);
    } 
  }


  void updateOrbit(float dt) {
    orbitAngle += orbitVel * dt;
    orbitAngle %= TWO_PI;
    pos.x = orbitRadius * cos(orbitAngle);
    pos.z = orbitRadius * sin(orbitAngle);
    lookAt.set(0,0,0);
  }

  void updateFly(float dt) {
    float mouseXScale = (mouseX - width / 2) * 0.2;
    float mouseYScale = -(mouseY - height / 2) * 0.2;
    final float epsilon = 0.00001;
    mouseXScale = (mouseLocked && !becameLocked) ? mouseXScale : 0;
    mouseYScale = (mouseLocked && !becameLocked) ? mouseYScale : 0;
    becameLocked = false;

    azVel += mouseXScale * dt*10;
    altVel += mouseYScale * dt*10;

    float dampRDt = pow(dampR, dt);
    float dampMDt = pow(dampM, dt);

    az += azVel * (1 - dampRDt) / log(dampR);
    alt += altVel * (1 - dampRDt) / log(dampR);

    azVel *= dampRDt;
    altVel *= dampRDt;

    az = (az % TWO_PI + TWO_PI) % TWO_PI;
    alt = constrain(alt, -PI_2+epsilon, PI_2-epsilon);

    vpn.x = cos(alt) * cos(az);
    vpn.y = sin(alt);
    vpn.z = cos(alt) * sin(az);
    vpn.normalize();

    PVector scaledVel = PVector.mult(vel, (1 - dampMDt) / log(dampM));
    pos.add(scaledVel);
    // friction
    vel.mult(dampMDt);

    lookAt = PVector.add(pos, PVector.mult(vpn, 10));

    // is origin behind camera?
    PVector originDir = PVector.sub(new PVector(0,0, 0), new PVector(pos.x, pos.y, 0));
    isOriginBehindCamera = (vpn.dot(originDir) < 0); 
    // if (isOriginBehindCamera) {
    //   println("BEHIND", originDir.toString());
    // }
  }
}


void checkSendOsc() {
  if (! posPrev.equals(cam.pos) ) {
    OscMessage posMsg = new OscMessage("/camcontrol/cam/pos");
    posMsg.add(cam.pos.x);
    posMsg.add(cam.pos.y);
    posMsg.add(cam.pos.z);
    oscP5.send(posMsg, remoteAddr);
    posPrev = cam.pos.copy();
  }

  if (! lookatPrev.equals(cam.lookAt)) {
    OscMessage lookAtMsg = new OscMessage("/camcontrol/cam/lookat");
    lookAtMsg.add(cam.lookAt.x);
    lookAtMsg.add(cam.lookAt.y);
    lookAtMsg.add(cam.lookAt.z);
    oscP5.send(lookAtMsg, remoteAddr);
    lookatPrev = cam.lookAt.copy();
  }
}


void sendOscFloat(String oscId, float value) {
  OscMessage msg = new OscMessage(oscId);
  msg.add(value);
  oscP5.send(msg, remoteAddr);
}


int[] getViewPortSize(int scrWidth, int scrHeight, float aspect) {
  int[] result = new int[2];
  
  if (aspect < 1) { // portrait
    result[0] = (int)(scrWidth * aspect);
    result[1] = scrHeight;
  }
  else {
    result[0] = scrWidth;
    result[1] = (int)(scrHeight / aspect);
  }

  return result;
}


void resizeViewport() {
  int[] vpDims = getViewPortSize(width, height, cam.aspect);
  viewport = createGraphics(vpDims[0], vpDims[1], P3D);
}



PVector findIntersection2D(PVector line1p1, PVector line1p2, PVector line2p1, PVector line2p2) {
  float x1 = line1p1.x, y1 = line1p1.y;
  float x2 = line1p2.x, y2 = line1p2.y;
  float x3 = line2p1.x, y3 = line2p1.y;
  float x4 = line2p2.x, y4 = line2p2.y;

  // Calculate the parts of the line equation
  float denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
  if (denom == 0) return null; // Lines are parallel

  float t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
  float u = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom;

  // Check if the scalar parameters are within the bounds of 0 and 1
  if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
    float intersectX = x1 + t * (x2 - x1);
    float intersectY = y1 + t * (y2 - y1);
    return new PVector(intersectX, intersectY);
  }

  return null; // No intersection within the bounds of the line segments
}

