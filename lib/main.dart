import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GasolineProCalculator(),
    ));

class GasolineProCalculator extends StatefulWidget {
  @override
  _GasolineProCalculatorState createState() => _GasolineProCalculatorState();
}

class _GasolineProCalculatorState extends State<GasolineProCalculator> {
  final int rowCount = 10; // زيادة عدد الصفوف لـ 10
  late List<Map<String, TextEditingController>> rowsData;
  final ScreenshotController screenshotController = ScreenshotController();
  
  String productGrade = "95"; 

  // كافة متغيرات النتائج النهائية لكل الخصائص
  double totalLevel = 0.0, ethyl135 = 0.0, finalOct = 0.0, finalSens = 0.0, 
         finalDen = 0.0, finalAr = 0.0, finalBen = 0.0, finalOle = 0.0, 
         finalRvp = 0.0, finalS = 0.0;

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
        row[key] = TextEditingController(text: (key == 'tank' || key == 'prod') ? '' : '0');
        row[key]!.addListener(() {
          _saveData(index, key, row[key]!.text);
          _calculateAll();
        });
      });
      return row;
    });
    _loadSavedData();
  }

  _saveData(int index, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('row_${index}_$key', value);
  }

  _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < rowCount; i++) {
      rowsData[i].forEach((key, controller) {
        controller.text = prefs.getString('row_${i}_$key') ?? controller.text;
      });
    }
    _calculateAll();
  }

  void _calculateAll() {
    double tLvl = 0, wOct = 0, wSens = 0, wDen = 0, wAr = 0, wBen = 0, wOle = 0, wS = 0, rvpSum = 0;
    double sumRJ = 0, sumO2 = 0;

    for (var r in rowsData) tLvl += double.tryParse(r["level"]!.text) ?? 0;

    if (tLvl > 0) {
      for (var r in rowsData) {
        double l = double.tryParse(r["level"]!.text) ?? 0;
        double ratio = l / tLvl;
        
        wOct += ratio * (double.tryParse(r["oct"]!.text) ?? 0);
        wSens += ratio * (double.tryParse(r["sens"]!.text) ?? 0);
        wDen += ratio * (double.tryParse(r["den"]!.text) ?? 0);
        wAr += ratio * (double.tryParse(r["ar"]!.text) ?? 0);
        wBen += ratio * (double.tryParse(r["ben"]!.text) ?? 0);
        wOle += ratio * (double.tryParse(r["ole"]!.text) ?? 0);
        wS += ratio * (double.tryParse(r["s"]!.text) ?? 0);
        
        sumRJ += ratio * (double.tryParse(r["oct"]!.text) ?? 0) * (double.tryParse(r["sens"]!.text) ?? 0);
        sumO2 += ratio * pow((double.tryParse(r["ole"]!.text) ?? 0), 2);
        
        double rvp = double.tryParse(r["rvp"]!.text) ?? 0;
        if (rvp > 0) rvpSum += ratio * pow(rvp, 1.25);
      }
      ethyl135 = wOct + (0.03324 * (sumRJ - (wOct * wSens))) + (0.00085 * (sumO2 - pow(wOle, 2)));
    }

    setState(() {
      totalLevel = tLvl; finalOct = wOct; finalSens = wSens; finalDen = wDen;
      finalAr = wAr; finalBen = wBen; finalOle = wOle; finalS = wS;
      finalRvp = tLvl > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  Color _getSpecColor(String type, double value) {
    if (productGrade == "95") {
      if (type == "OCT") return value >= 95.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return value <= 0.9 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return value <= 33.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return value <= 0.7 ? Colors.greenAccent : Colors.redAccent;
    } else {
      if (type == "OCT") return value >= 92.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return value <= 1.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return value <= 35.0 ? Colors.greenAccent : Colors.redAccent;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Text("Gasoline Blending Calculator", style: TextStyle(fontSize: 15, color: Colors.white)),
        actions: [
          DropdownButton<String>(
            value: productGrade,
            dropdownColor: Colors.blueGrey[900],
            underline: Container(),
            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text("Grade $s "))).toList(),
            onChanged: (v) => setState(() => productGrade = v!),
          ),
          IconButton(icon: Icon(Icons.print, color: Colors.orangeAccent), onPressed: _showRecipeDialog)
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
                  columnSpacing: 8,
                  horizontalMargin: 5,
                  headingRowHeight: 35,
                  dataRowHeight: 32,
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                  border: TableBorder.all(color: Colors.grey[800]!),
                  columns: ['Tank', 'Prod', 'Level', 'Oct', 'Sens', 'Den', 'Ar%', 'Ben%', 'Ole%', 'RVP', 'S%']
                      .map((h) => DataColumn(label: Text(h, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))).toList(),
                  rows: [
                    ...rowsData.map((row) => DataRow(cells: [
                      _inputCell(row['tank']!, 45, true), _inputCell(row['prod']!, 60, true),
                      _inputCell(row['level']!, 45, false), _inputCell(row['oct']!, 35, false),
                      _inputCell(row['sens']!, 35, false), _inputCell(row['den']!, 55, false),
                      _inputCell(row['ar']!, 35, false), _inputCell(row['ben']!, 35, false),
                      _inputCell(row['ole']!, 35, false), _inputCell(row['rvp']!, 40, false),
                      _inputCell(row['s']!, 35, false),
                    ])).toList(),
                    // صف النتائج النهائية الملون حسب المواصفة
                    DataRow(color: MaterialStateProperty.all(Colors.blueGrey[900]), cells: [
                      DataCell(Text("FINAL", style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold))),
                      DataCell(Text(productGrade, style: TextStyle(color: Colors.white, fontSize: 10))),
                      DataCell(Text(totalLevel.toStringAsFixed(0), style: TextStyle(color: Colors.white, fontSize: 10))),
                      DataCell(_specBox(ethyl135.toStringAsFixed(1), _getSpecColor("OCT", ethyl135))),
                      DataCell(_td(finalSens.toStringAsFixed(1))),
                      DataCell(_td(finalDen.toStringAsFixed(4))),
                      DataCell(_specBox(finalAr.toStringAsFixed(1), _getSpecColor("AR", finalAr))),
                      DataCell(_specBox(finalBen.toStringAsFixed(2), _getSpecColor("BEN", finalBen))),
                      DataCell(_td(finalOle.toStringAsFixed(1))),
                      DataCell(_specBox(finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp))),
                      DataCell(_td(finalS.toStringAsFixed(1))),
                    ])
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _td(String t) => Text(t, style: TextStyle(color: Colors.white, fontSize: 10));

  Widget _specBox(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.2), border: Border.all(color: c, width: 0.5)),
    child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, 
      textAlign: TextAlign.center, 
      keyboardType: isTxt ? TextInputType.text : TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: Colors.white, fontSize: 10),
      decoration: InputDecoration(border: InputBorder.none, isDense: true),
    )),
  );

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(15),
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Gasoline Blending Calculator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey[900])),
              Text("App by Mohammed Nofal", style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
              Divider(thickness: 1),
              Text("Blending Components", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Table(
                border: TableBorder.all(color: Colors.black12),
                children: [
                  TableRow(decoration: BoxDecoration(color: Colors.grey[200]), children: [
                    _rh("Tank"), _rh("Prod"), _rh("Level"), _rh("Oct"), _rh("Den"), _rh("RVP")
                  ]),
                  ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(children: [
                    _rd(r['tank']!.text), _rd(r['prod']!.text), _rd(r['level']!.text),
                    _rd(r['oct']!.text), _rd(r['den']!.text), _rd(r['rvp']!.text),
                  ])).toList(),
                ],
              ),
              Divider(height: 20),
              Text("FINAL SPECIFICATION (RESULT)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[900])),
              SizedBox(height: 5),
              _recipeRow("ETHYL OCTANE:", ethyl135.toStringAsFixed(2)),
              _recipeRow("TOTAL LEVEL (cm):", totalLevel.toStringAsFixed(1)),
              _recipeRow("FINAL DENSITY:", finalDen.toStringAsFixed(4)),
              _recipeRow("AROMATICS %:", finalAr.toStringAsFixed(2)),
              _recipeRow("BENZENE %:", finalBen.toStringAsFixed(2)),
              _recipeRow("RVP:", finalRvp.toStringAsFixed(2)),
              _recipeRow("SULFUR %:", finalS.toStringAsFixed(2)),
              SizedBox(height: 10),
              Text("Date: ${DateTime.now().toString().substring(0,16)}", style: TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
        ElevatedButton(onPressed: _saveImg, child: Text("Save Image")),
      ],
    ));
  }

  Widget _rh(String t) => Padding(padding: EdgeInsets.all(3), child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)));
  Widget _rd(String t) => Padding(padding: EdgeInsets.all(3), child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 9)));

  Widget _recipeRow(String l, String v) => Padding(
    padding: EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(fontSize: 10)),
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    ]),
  );

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to Gallery!")));
    }
  }
}
