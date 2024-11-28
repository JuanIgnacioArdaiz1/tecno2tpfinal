// ---- Librerías ----
import gab.opencv.*;
import processing.core.*;
import processing.video.*;
import fisica.*;
import ddf.minim.*;
import ddf.minim.analysis.*;

// ---- Variables globales ----
boolean pruebaCamara = false;
PImage img;
OpenCV opencv;
FWorld world;
ArrayList<FCircle> balls;
FPoly poly;
Capture camara;

AudioPlayer abucheo, risas, tomatazo;

Minim minim;
AudioInput mic;
FFT fft;

float AMP_MIN = 0.5; //0.05
float AMP_MAX = 0.7; //0.150
float FREC_MIN = 20; //20
float FREC_MAX = 550; //550

GestorSenial gestorAmp;
GestorSenial gestorPitch;

boolean monitorear = false;
boolean haySonido;
boolean antesHabiaSonido;

float DIALOGO_UMBRAL = 0.05; //0.05
float DIALOGO_DURACION = 10000; //3000

float APLAUSO_UMBRAL = 0.15; //0.15
int APLAUSO_COOLDOWN = 0; //300

boolean hayDialogo = false;
boolean hayAplauso = false;

int dialogoInicio;
int aplausoUltimoTiempo;

AudioInput in;

FCircle ondaExpansiva;
int ancho = 640;
int alto = 480;
int umbral = 120; //40 en lo de Joaco
float fillProgress = 0;
boolean isFilledRed = false;
int redOpacity = 20;

float centroidX = 0;
float centroidY = 0;
float interpolatedX = 0;
float interpolatedY = 0;
float smoothFactor = 0.1; // Factor de suavizado (0.0 - sin cambio, 1.0 - salto inmediato) Valores bajos (e.g., 0.05): Movimiento más suave, pero más lento. Valores altos (e.g., 0.5):

// Variables para la animación
PImage[] frames; // Almacenará las imágenes PNG
int frameCount = 120; // Número de imágenes en la secuencia
int lastTomateTime = 0;

// variables tomates
ArrayList<TomateAnimado> tomates;

// ---- Configuración inicial ----
void setup() {
  size(640, 480);

  iniciarSeniales();
  iniciarAudio();
  iniciarFisica();
  iniciarCamara();
  iniciarOpenCV();
  iniciarOndaExpansiva();
  tomates = new ArrayList<TomateAnimado>();
  frames = new PImage[frameCount];
  for (int i = 0; i < frameCount; i++) {
    String filename = "data/frame" + nf(i + 1, 4) + ".png"; // Nombra los archivos correctamente
    frames[i] = loadImage(filename);
  }
}

// ---- Bucle principal ----
void draw() {
  background(120);

  detectarDialogo();
  detectarAplauso();
  monitorearSenales();
  procesarCamara();
  actualizarFisica();
  ajustarOndaExpansiva();
  dibujarOndaExpansiva();
  crearPelotitas();
}

// ---- Inicializaciones ----
void iniciarSeniales() {
  gestorAmp = new GestorSenial(AMP_MIN, AMP_MAX);
  gestorPitch = new GestorSenial(FREC_MIN, FREC_MAX);
}

void iniciarAudio() {
  minim = new Minim(this);
  mic = minim.getLineIn(Minim.MONO, 512);
  fft = new FFT(mic.bufferSize(), mic.sampleRate());

  // Cargamos los audios desde la carpeta data
  abucheo = minim.loadFile("data/abucheo.mp3");
  risas = minim.loadFile("data/risas.mp3");
  tomatazo = minim.loadFile("data/tomatazo.mp3");

  // Ajustamos el vol de cada audio
  abucheo.setGain(-5); // Reduce el vol en decibeles
  risas.setGain(-10);  // Reduce más el vol
  tomatazo.setGain(-5); // vol normal
}

void iniciarFisica() {
  Fisica.init(this);
  world = new FWorld();
  world.setGravity(0, 300);
  balls = new ArrayList<FCircle>();
}

void iniciarCamara() {
  String[] listaDeCamaras = Capture.list();
  if (listaDeCamaras.length == 0) {
    println("No se encontraron cámaras.");
    exit();
  } else {
    camara = new Capture(this, listaDeCamaras[0]);
    camara.start();
  }
}

void iniciarOpenCV() {
  opencv = new OpenCV(this, ancho, alto);
  opencv.findContours();
}

void iniciarOndaExpansiva() {
  ondaExpansiva = new FCircle(10);
  ondaExpansiva.setStroke(5);
  ondaExpansiva.setFill(0, 255, 0);
  ondaExpansiva.setStrokeColor(color(0,255,0));
  ondaExpansiva.setPosition(width / 2, height / 2);
  ondaExpansiva.setStatic(true);
  world.add(ondaExpansiva);
}

// ---- Funciones de procesamiento ----
void detectarDialogo() {
  float nivelDialogo = mic.left.level();
  if (nivelDialogo > DIALOGO_UMBRAL) {
    if (!hayDialogo) {
      dialogoInicio = millis();
      hayDialogo = true;
    }
  } else if (hayDialogo && (millis() - dialogoInicio >= DIALOGO_DURACION)) {
    println("Hay diálogo");
    abucheo.rewind();
    abucheo.play();
    hayDialogo = false;
  }
}

void detectarAplauso() {
  float nivelAplauso = mic.left.level();
  if (nivelAplauso > APLAUSO_UMBRAL && millis() - aplausoUltimoTiempo > APLAUSO_COOLDOWN) {
    println("Hay onda expansiva");
    aplausoUltimoTiempo = millis();
  }
}

void monitorearSenales() {
  float vol = mic.left.level();
  gestorAmp.actualizar(vol);
  haySonido = gestorAmp.filtrada > AMP_MIN;

  boolean inicioElSonido = haySonido && !antesHabiaSonido;
  boolean finDelSonido = !haySonido && antesHabiaSonido;

  if (inicioElSonido) println("Inicio de sonido detectado");
  if (finDelSonido) println("Fin de sonido detectado");

  fft.forward(mic.mix);
  float frecuencia = obtenerFrecuenciaDominante();
  gestorPitch.actualizar(frecuencia);

  if (monitorear) {
    gestorAmp.dibujar(25, 25);
    gestorPitch.dibujar(225, 25);
  }

  antesHabiaSonido = haySonido;
}

void procesarCamara() {
  if (camara.available()) {
    camara.read();
    opencv.loadImage(camara);
    opencv.threshold(umbral);
    //opencv.invert();
  }
}

void actualizarFisica() {
  world.step();
  world.draw();
  findAndSimplifyLargestPolygon();
}

void ajustarOndaExpansiva() {
  float vol = mic.left.level();
  if (vol > AMP_MIN && vol < AMP_MAX) {
    float tam = map(vol, AMP_MIN, AMP_MAX, 10, 500);
    ondaExpansiva.setSize(tam);
    ondaExpansiva.setFill(0, 255, 0, 50);
  } else {
    ondaExpansiva.setSize(10);
    ondaExpansiva.setFill(0, 0);
  }
}

void dibujarOndaExpansiva() {
  stroke(0, 255, 0, 150);
  strokeWeight(2);
  noFill();
  ellipse(ondaExpansiva.getX(), ondaExpansiva.getY(), ondaExpansiva.getSize(), ondaExpansiva.getSize());
}

void crearPelotitas() {
  float vol = mic.left.level();
  if (vol > AMP_MIN && vol < AMP_MAX && millis() - lastTomateTime > 300) { // Cada segundo aprox.
    createTomate();
    lastTomateTime = millis();
  }
  for (TomateAnimado tomate : tomates) {
    tomate.dibujar();
  }
}

// ---- Funciones auxiliares ----
float obtenerFrecuenciaDominante() {
  int indexMayor = 0;
  float maxAmp = -1;
  for (int i = 0; i < fft.specSize(); i++) {
    if (fft.getBand(i) > maxAmp) {
      maxAmp = fft.getBand(i);
      indexMayor = i;
    }
  }
  return fft.indexToFreq(indexMayor);
}

void findAndSimplifyLargestPolygon() {
  if (poly != null) world.remove(poly);

  opencv.findContours();
  ArrayList<Contour> contours = opencv.findContours();

  if (contours.size() > 0) {
    Contour largestContour = contours.get(0);
    for (Contour contour : contours) {
      if (contour.area() > largestContour.area()) largestContour = contour;
    }

    largestContour = largestContour.getPolygonApproximation();
    poly = new FPoly();
    ArrayList<PVector> points = largestContour.getPoints();

    // Calcular centroide
    float sumX = 0;
    float sumY = 0;
    for (PVector point : points) {
      poly.vertex(point.x, point.y);
      sumX += point.x;
      sumY += point.y;
    }
    centroidX = sumX / points.size();
    centroidY = sumY / points.size();

    // Suavizar transición entre centroides
    interpolatedX = lerp(interpolatedX, centroidX, smoothFactor);
    interpolatedY = lerp(interpolatedY, centroidY, smoothFactor);

    poly.setStatic(true);

    // Establecer el color solo si no está lleno de rojo
    if (!isFilledRed) {
      poly.setFill(0, 255, 0, 0);
    } else {
      poly.setFill(255, 0, 0, redOpacity);
    }

    world.add(poly);

    // Actualizar posición de la onda expansiva
    ondaExpansiva.setPosition(interpolatedX, interpolatedY);
  }
}

void createTomate() {
  TomateAnimado tomate = new TomateAnimado(20, frames);
  float xStart;
  float velocityX;
  tomate.circulo.setRestitution(10.0);

  // Lado aleatorio
  if (random(1) < 0.5) {
    xStart = 10; // Lado izquierdo
    velocityX = random(300, 500); // Velocidad hacia la derecha
  } else {
    xStart = width - 10; // Lado derecho
    velocityX = random(-300, -150); // Velocidad hacia la izquierda
  }

  // Posición inicial aleatoria en Y
  tomate.circulo.setPosition(xStart, random(50, 150));
  tomate.circulo.setDensity(1.0);
  tomate.circulo.setVelocity(velocityX, random(-100, -200));
  world.add(tomate.circulo);
  tomates.add(tomate);
}
class TomateAnimado {
  FCircle circulo;
  PImage[] frames;
  int currentFrame;

  TomateAnimado(float radius, PImage[] frames) {
    this.circulo = new FCircle(radius);
    this.frames = frames;
    this.currentFrame = 0;
    this.circulo.setFill(0, 0); // Invisible por defecto
    this.circulo.setStroke(0, 0);
  }

  void dibujar() {
    // Sincronizar posición del video con el círculo
    imageMode(CENTER);
    image(frames[currentFrame], circulo.getX(), circulo.getY(), 96, 54);

    // Avanzar al siguiente frame
    currentFrame = (currentFrame + 1) % frames.length;
  }
}

void contactStarted(FContact c) {

  if ((c.getBody1() instanceof FCircle && c.getBody2() == poly) ||
    (c.getBody2() instanceof FCircle && c.getBody1() == poly)) {
    fillProgress = min(fillProgress + 0.1, 1.0); // Incrementa hasta 100%
    isFilledRed = true;
    redOpacity = min(redOpacity + 10, 255); // Aumentar opacidad hasta 255
    poly.setFill(255, 0, 0, redOpacity); // Cambiar a rojo con nueva opacidad

    // Eliminar la pelota tras la colisión
    FBody tomateBody = (c.getBody1() instanceof FCircle) ? c.getBody1() : c.getBody2();

    // Buscar el TomateAnimado correspondiente al FCircle
    TomateAnimado tomateAEliminar = null;
    for (TomateAnimado tomate : tomates) {
      if (tomate.circulo == tomateBody) {
        tomateAEliminar = tomate;
        break;
      }
    }

    if (tomateAEliminar != null) {
      world.remove(tomateAEliminar.circulo); // Eliminar del mundo
      tomates.remove(tomateAEliminar); // Eliminar de la lista
      tomatazo.rewind();
      tomatazo.play();
    }
  }
}

void stop() {
  mic.close();
  minim.stop();
  super.stop();
}

void keyPressed(){
if(key=='r') {
 poly.setFill(0, 255, 0, 0);
 redOpacity = 0;
}



}
