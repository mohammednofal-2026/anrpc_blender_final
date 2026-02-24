import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: GasolineProCalculator(),
    ));

class GasolineProCalculator extends StatefulWidget {
  @override
  _GasolineProCalculatorState createState() => _GasolineProCalculatorState();
}

class _GasolineProCalculatorState extends State<GasolineProCalculator> {
  final int rowCount = 8;
  late List<Map<String, TextEditingController>> rowsData;
  final ScreenshotController screenshotController = ScreenshotController();
  
  // متغيرات النتائج النهائية
  double totalLevel = 0.0, ethyl135 = 0.0, finalOctane = 0.0, 
         finalRvp = 0.0, finalDensity = 0.0, finalAr = 0.0, 
         finalBen = 0.0, finalSens = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    rowsData = List.generate(rowCount, (index) {
      var row = <String, TextEditingController>{};
      ['tank', 'prod', 'level', 'oct', 'sens', 'den', 'ar', 'ben', 'ole', 'rvp', 's']
          .forEach((key) {
        row[key] = TextEditingController();
        row[key]!.addListener(() {
          _saveData(index, key, row[key]!.text);
          _calculateAll();
        });
      });
      return row;
    });
    _loadSavedData();
  }

  // حفظ البيانات لحظياً
  _saveData(int index, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('row_${index}_$key', value);
  }

  // تحميل البيانات المحفوظة عند فتح التطبيق
  _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < rowCount; i++) {
      rowsData[i].forEach((key, controller) {
        String? savedValue = prefs.getString('row_${i}_$key');
        if (savedValue != null) {
          controller.text = savedValue;
        } else {
          // قيم افتراضية
          controller.text = (key == 'tank' || key == 'prod') ? '' : '0';
        }
      });
    }
    _calculateAll();
  }

  void _calculateAll() {
    double tempTLevel = 0, tempWOct = 0, tempWSens = 0, tempWDen = 0, 
           tempWAr = 0, tempWOle = 0, tempWBen = 0, rvpSum = 0;
    double sumRJ = 0, sumO2 = 0;

    for (var row in rowsData) {
      tempTLevel += double.tryParse(row["level"]!.text) ?? 0;
    }

    if (tempTLevel > 0) {
      for (var row in rowsData) {
        double level = double.tryParse(row["level"]!.text) ?? 0;
        double ratio = level / tempTLevel;
        
        double oct = double.tryParse(row["oct"]!.text) ?? 0;
        double sens = double.tryParse(row["sens"]!.text) ?? 0;
        double den = double.tryParse(row["den"]!.text) ?? 0;
        double ar = double.tryParse(row["ar"]!.text) ?? 0;
        double ben = double.tryParse(row["ben"]!.text) ?? 0;
        double ole = double.tryParse(row["ole"]!.text) ?? 0;
        double rvp = double.tryParse(row["rvp"]!.text) ?? 0;

        tempWOct += (ratio * oct);
        tempWSens += (ratio * sens);
        tempWAr += (ratio * ar);
        tempWOle += (ratio * ole);
        tempWDen += (ratio * den);
        tempWBen += (ratio * ben);
        
        sumRJ += (ratio * oct * sens);
        sumO2 += (ratio * pow(ole, 2));
        
        if (rvp > 0) rvpSum += ratio * pow(rvp, 1.25);
      }
      
      // معادلة Ethyl-135 المعقدة
      ethyl135 = tempWOct + 
                 (0.03324 * (sumRJ - (tempWOct * tempWSens))) + 
                 (0.00085 * (sumO2 - pow(tempWOle, 2)));
    }

    setState(() {
      totalLevel = tempTLevel;
      finalOctane = tempWOct;
      finalSens = tempWSens;
      finalDensity = tempWDen;
      finalAr = tempWAr;
      finalBen = tempWBen;
      finalRvp = totalLevel > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("ANRPC BLENDER", 
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_camera, color: Colors.greenAccent),
            onPressed: _showRecipeDialog
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 15,
                  horizontalMargin: 10,
                  headingRowHeight: 45,
                  dataRowHeight: 40,
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[900]),
                  border: TableBorder.all(color: Colors.grey[300]!),
                  columns: ['Tank', 'Prod.', 'Level', 'Oct', 'Den', 'Ar%', 'Ben%', 'RVP']
                      .map((h) => DataColumn(
                          label: Text(h, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                      .toList(),
                  rows: rowsData.map((row) => DataRow(cells: [
                        _inputCell(row['tank']!, 55, isText: true),
                        _inputCell(row['prod']!, 75, isText: true),
                        _inputCell(row['level']!, 55),
                        _inputCell(row['oct']!, 45),
                        _inputCell(row['den']!, 65),
                        _inputCell(row['ar']!, 45),
                        _inputCell(row['ben']!, 45),
                        _inputCell(row['rvp']!, 50),
                      ])).toList(),
                ),
              ),
            ),
          ),
          _buildSummaryBar(),
        ],
      ),
    );
  }

  DataCell _inputCell(TextEditingController c, double w, {bool isText = false}) => DataCell(
        Container(
          width: w,
          child: TextField(
            controller: c,
            keyboardType: isText ? TextInputType.text : TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
      );

  Widget _buildSummaryBar() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 10,
        runSpacing: 10,
        children: [
          _stat("ETHYL OCT", ethyl135.toStringAsFixed(2), Colors.orangeAccent),
          _stat("TOTAL LVL", totalLevel.toStringAsFixed(1), Colors.white),
          _stat("DENSITY", finalDensity.toStringAsFixed(4), Colors.cyanAccent),
          _stat("AR%", finalAr.toStringAsFixed(1), Colors.greenAccent),
          _stat("RVP", finalRvp.toStringAsFixed(2), Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      );

  void _showRecipeDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: Screenshot(
                controller: screenshotController,
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("ANRPC PRODUCTION PLANNING",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.blue[900])),
                      SizedBox(height: 5),
                      Text("GASOLINE BLENDING RECIPE",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                      Divider(thickness: 2, height: 30),
                      _recipeRow("ETHYL-135 OCTANE:", ethyl135.toStringAsFixed(2)),
                      _recipeRow("TOTAL LEVEL (cm):", totalLevel.toStringAsFixed(1)),
                      _recipeRow("FINAL DENSITY:", finalDensity.toStringAsFixed(4)),
                      _recipeRow("AROMATICS %:", finalAr.toStringAsFixed(2)),
                      _recipeRow("RVP:", finalRvp.toStringAsFixed(2)),
                      SizedBox(height: 20),
                      Text("Generated by ANRPC Blender App",
                          style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  onPressed: _saveAsImage, 
                  child: Text("Save to Gallery", style: TextStyle(color: Colors.white))
                ),
              ],
            ));
  }

  void _saveAsImage() async {
    final Uint8List? image = await screenshotController.capture();
    if (image != null) {
      final result = await ImageGallerySaver.saveImage(image, 
        name: "ANRPC_Recipe_${DateTime.now().millisecondsSinceEpoch}");
      
      Navigator.pop(context);
      
      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text("Recipe Saved Successfully!"))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Failed to save image"))
        );
      }
    }
  }

  Widget _recipeRow(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[900])),
          ],
        ),
      );
}
