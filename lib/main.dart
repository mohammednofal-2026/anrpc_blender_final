import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
  
  String productGrade = "95";
  String season = "Summer"; 

  double totalLevel = 0.0, ethyl135 = 0.0, finalDen = 0.0, finalAr = 0.0, 
         finalBen = 0.0, finalRvp = 0.0, finalOle = 0.0, finalS = 0.0, finalSens = 0.0;

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
        row[key]!.addListener(() => _calculateAll());
      });
      return row;
    });
  }

  void _calculateAll() {
    double tLvl = 0, wOct = 0, wSens = 0, wDen = 0, wAr = 0, wBen = 0, wOle = 0, wS = 0, rvpSum = 0;
    double sumRJ = 0, sumO2 = 0;

    for (var r in rowsData) tLvl += double.tryParse(r["level"]!.text) ?? 0;

    if (tLvl > 0) {
      for (var r in rowsData) {
        double l = double.tryParse(r["level"]!.text) ?? 0;
        double ratio = l / tLvl;
        double oct = double.tryParse(r["oct"]!.text) ?? 0;
        double sens = double.tryParse(r["sens"]!.text) ?? 0;
        double ole = double.tryParse(r["ole"]!.text) ?? 0;

        wOct += ratio * oct;
        wSens += ratio * sens;
        wDen += ratio * (double.tryParse(r["den"]!.text) ?? 0);
        wAr += ratio * (double.tryParse(r["ar"]!.text) ?? 0);
        wBen += ratio * (double.tryParse(r["ben"]!.text) ?? 0);
        wOle += ratio * ole;
        wS += ratio * (double.tryParse(r["s"]!.text) ?? 0);
        sumRJ += ratio * oct * sens;
        sumO2 += ratio * pow(ole, 2);
        double rvp = double.tryParse(r["rvp"]!.text) ?? 0;
        if (rvp > 0) rvpSum += ratio * pow(rvp, 1.25);
      }
      ethyl135 = wOct + (0.03324 * (sumRJ - (wOct * wSens))) + (0.00085 * (sumO2 - pow(wOle, 2)));
    }

    setState(() {
      totalLevel = tLvl; finalSens = wSens; finalDen = wDen;
      finalAr = wAr; finalBen = wBen; finalOle = wOle; finalS = wS;
      finalRvp = tLvl > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  Color _getSpecColor(String type, double val) {
    double rvpLimit = (season == "Summer") ? 0.63 : 0.72;
    
    if (productGrade == "95") {
      switch (type) {
        case "OCT": return val >= 95 ? Colors.greenAccent : Colors.redAccent;
        case "SENS": return val >= 10 ? Colors.greenAccent : Colors.redAccent;
        case "S": return val <= 10 ? Colors.greenAccent : Colors.redAccent;
        case "BEN": return val <= 1.0 ? Colors.greenAccent : Colors.redAccent;
        case "AR": return val <= 42 ? Colors.greenAccent : Colors.redAccent;
        case "OLE": return val <= 18 ? Colors.greenAccent : Colors.redAccent;
        case "RVP": return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
      }
    } else { // Grade 92
      switch (type) {
        case "OCT": return val >= 92 ? Colors.greenAccent : Colors.redAccent;
        case "SENS": return val >= 8.1 ? Colors.greenAccent : Colors.redAccent;
        case "S": return val <= 150 ? Colors.greenAccent : Colors.redAccent;
        case "BEN": return val <= 3.0 ? Colors.greenAccent : Colors.redAccent;
        case "AR": return val <= 42 ? Colors.greenAccent : Colors.redAccent;
        case "OLE": return val <= 18 ? Colors.greenAccent : Colors.redAccent;
        case "RVP": return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
      }
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: Colors.blueGrey[900],
        title: Text("Gasoline Blending Calculator", style: TextStyle(fontSize: 12)),
        actions: [
          DropdownButton<String>(
            value: season,
            underline: Container(),
            items: ["Summer", "Winter"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => season = v!),
          ),
          DropdownButton<String>(
            value: productGrade,
            underline: Container(),
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text(" G-$s ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
            onChanged: (v) => setState(() => productGrade = v!),
          ),
          IconButton(icon: Icon(Icons.receipt_long, color: Colors.orangeAccent, size: 20), onPressed: _showRecipeDialog),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: DataTable(
                  columnSpacing: 8,
                  horizontalMargin: 5,
                  headingRowHeight: 40,
                  dataRowHeight: 32,
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                  border: TableBorder.all(color: Colors.grey[800]!),
                  columns: ['Tank', 'Prod', 'Level', 'Oct', 'Sens', 'Ar%', 'Ben%', 'Ole%', 'RVP', 'S']
                      .map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))).toList(),
                  rows: [
                    ...rowsData.map((row) => DataRow(cells: [
                      _inputCell(row['tank']!, 45, true), _inputCell(row['prod']!, 55, true),
                      _inputCell(row['level']!, 40, false), _inputCell(row['oct']!, 35, false),
                      _inputCell(row['sens']!, 35, false), _inputCell(row['ar']!, 35, false),
                      _inputCell(row['ben']!, 35, false), _inputCell(row['ole']!, 35, false),
                      _inputCell(row['rvp']!, 40, false), _inputCell(row['s']!, 35, false),
                    ])).toList(),
                    DataRow(color: MaterialStateProperty.all(Colors.blueGrey[900]), cells: [
                      DataCell(Text("FINAL", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 9))),
                      DataCell(Text(productGrade, style: TextStyle(fontSize: 9))),
                      DataCell(Text(totalLevel.toStringAsFixed(0), style: TextStyle(fontSize: 9))),
                      DataCell(_specBox(ethyl135.toStringAsFixed(1), _getSpecColor("OCT", ethyl135))),
                      DataCell(_specBox(finalSens.toStringAsFixed(1), _getSpecColor("SENS", finalSens))),
                      DataCell(_specBox(finalAr.toStringAsFixed(1), _getSpecColor("AR", finalAr))),
                      DataCell(_specBox(finalBen.toStringAsFixed(2), _getSpecColor("BEN", finalBen))),
                      DataCell(_specBox(finalOle.toStringAsFixed(1), _getSpecColor("OLE", finalOle))),
                      DataCell(_specBox(finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp))),
                      DataCell(_specBox(finalS.toStringAsFixed(0), _getSpecColor("S", finalS))),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specBox(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.15), border: Border.all(color: c, width: 0.5)),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10),
      keyboardType: isTxt ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(border: InputBorder.none),
    )),
  );

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.all(8),
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          width: 600,
          color: Colors.white,
          padding: EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("GASOLINE BLENDING REPORT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blue[900], fontSize: 10, fontWeight: FontWeight.bold)),
                Divider(color: Colors.black45),
                _recipeTable(),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
                  child: Column(
                    children: [
                      Text("FINAL BATCH RESULTS ($productGrade - $season)", style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 10)),
                      SizedBox(height: 6),
                      _recipeResultRow("ETHYL OCTANE", ethyl135.toStringAsFixed(2)),
                      _recipeResultRow("SENSITIVITY", finalSens.toStringAsFixed(1)),
                      _recipeResultRow("AROMATICS %", finalAr.toStringAsFixed(1)),
                      _recipeResultRow("BENZENE %", finalBen.toStringAsFixed(2)),
                      _recipeResultRow("OLEFINS %", finalOle.toStringAsFixed(1)),
                      _recipeResultRow("SULFUR (ppm)", finalS.toStringAsFixed(1)),
                      _recipeResultRow("VAPOR PRESSURE (RVP)", finalRvp.toStringAsFixed(2)),
                      _recipeResultRow("DENSITY @15°C", finalDen.toStringAsFixed(4)),
                      Divider(),
                      _recipeResultRow("TOTAL BATCH LEVEL", "${totalLevel.toStringAsFixed(1)} cm"),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text("Generated: ${DateTime.now().toString().substring(0,16)}", style: TextStyle(color: Colors.grey, fontSize: 7)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(onPressed: _saveImg, child: Text("Save to Gallery")),
      ],
    ));
  }

  Widget _recipeTable() {
    return Table(
      border: TableBorder.all(color: Colors.black26),
      children: [
        TableRow(decoration: BoxDecoration(color: Colors.grey[300]), children: [
          _th("Tank"), _th("Product"), _th("Level"), _th("Oct")
        ]),
        ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
          children: [_td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
        )).toList()
      ],
    );
  }

  Widget _th(String t) => Padding(padding: EdgeInsets.all(3), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(3), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 9), textAlign: TextAlign.center));
  Widget _recipeResultRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w500)),
      Text(v, style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
    ]),
  );

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
    }
  }
}
