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
      totalLevel = tLvl; finalSens = wSens; finalDen = wDen;
      finalAr = wAr; finalBen = wBen; finalOle = wOle; finalS = wS;
      finalRvp = tLvl > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  Color _getSpecColor(String type, double val) {
    double rvpLimit = (season == "Summer") ? 0.63 : 0.72;
    if (productGrade == "95") {
      if (type == "OCT") return val >= 95 ? Colors.greenAccent : Colors.redAccent;
      if (type == "SENS") return val >= 10 ? Colors.greenAccent : Colors.redAccent;
      if (type == "S") return val <= 10 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 1.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 42 ? Colors.greenAccent : Colors.redAccent;
      if (type == "OLE") return val <= 18 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
    } else {
      if (type == "OCT") return val >= 92 ? Colors.greenAccent : Colors.redAccent;
      if (type == "SENS") return val >= 8.1 ? Colors.greenAccent : Colors.redAccent;
      if (type == "S") return val <= 150 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 3.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 42 ? Colors.greenAccent : Colors.redAccent;
      if (type == "OLE") return val <= 18 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
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
        title: Text("Gas Pro Blending", style: TextStyle(fontSize: 14)),
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
          IconButton(icon: Icon(Icons.print, color: Colors.orangeAccent), onPressed: _showRecipeDialog),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. جدول المدخلات - Fit for Screen
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: DataTable(
                  columnSpacing: 10,
                  horizontalMargin: 8,
                  headingRowHeight: 40,
                  dataRowHeight: 32,
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                  border: TableBorder.all(color: Colors.grey[800]!),
                  columns: ['Tank', 'Prod', 'Level', 'Oct', 'Sens', 'Ar%', 'Ben%', 'RVP']
                      .map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))).toList(),
                  rows: rowsData.map((row) => DataRow(cells: [
                    _inputCell(row['tank']!, 50, true), _inputCell(row['prod']!, 60, true),
                    _inputCell(row['level']!, 45, false), _inputCell(row['oct']!, 35, false),
                    _inputCell(row['sens']!, 35, false), _inputCell(row['ar']!, 35, false),
                    _inputCell(row['ben']!, 35, false), _inputCell(row['rvp']!, 40, false),
                  ])).toList(),
                ),
              ),
            ),
            // 2. الـ FINAL SPECIFICATION Dashboard - نتائج الخلطة كاملة
            _buildFinalSpecDashboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalSpecDashboard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text("FINAL SPECIFICATION RESULTS", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          Divider(color: Colors.grey[700], height: 20),
          _dashboardRow([
            _dashItem("ETHYL OCT", ethyl135.toStringAsFixed(2), _getSpecColor("OCT", ethyl135)),
            _dashItem("SENSITIVITY", finalSens.toStringAsFixed(1), _getSpecColor("SENS", finalSens)),
            _dashItem("DENSITY", finalDen.toStringAsFixed(4), Colors.cyanAccent),
          ]),
          SizedBox(height: 15),
          _dashboardRow([
            _dashItem("AROMATICS", "${finalAr.toStringAsFixed(1)}%", _getSpecColor("AR", finalAr)),
            _dashItem("BENZENE", "${finalBen.toStringAsFixed(2)}%", _getSpecColor("BEN", finalBen)),
            _dashItem("OLEFINS", "${finalOle.toStringAsFixed(1)}%", _getSpecColor("OLE", finalOle)),
          ]),
          SizedBox(height: 15),
          _dashboardRow([
            _dashItem("RVP", finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp)),
            _dashItem("SULFUR", "${finalS.toStringAsFixed(0)} ppm", _getSpecColor("S", finalS)),
            _dashItem("TOTAL LEVEL", "${totalLevel.toStringAsFixed(0)} cm", Colors.white),
          ]),
        ],
      ),
    );
  }

  Widget _dashboardRow(List<Widget> children) => Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children);

  Widget _dashItem(String label, String value, Color col) => Column(
    children: [
      Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 8, fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
      Text(value, style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.black)),
    ],
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
      insetPadding: EdgeInsets.all(10),
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          width: 500, color: Colors.white, padding: EdgeInsets.all(15),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("GASOLINE BLENDING RECIPE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blue[900], fontSize: 10, fontWeight: FontWeight.bold)),
                Divider(color: Colors.black45),
                _recipeTable(),
                SizedBox(height: 15),
                _recipeBox(),
                SizedBox(height: 10),
                Text("Date: ${DateTime.now().toString().substring(0,16)}", style: TextStyle(color: Colors.grey, fontSize: 8)),
              ],
            ),
          ),
        ),
      ),
      actions: [ElevatedButton(onPressed: _saveImg, child: Text("Save to Gallery"))],
    ));
  }

  Widget _recipeBox() => Container(
    padding: EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey[300]!)),
    child: Column(
      children: [
        _recipeResultRow("FINAL ETHYL OCTANE", ethyl135.toStringAsFixed(2)),
        _recipeResultRow("FINAL SENSITIVITY", finalSens.toStringAsFixed(1)),
        _recipeResultRow("FINAL AROMATICS %", finalAr.toStringAsFixed(1)),
        _recipeResultRow("FINAL BENZENE %", finalBen.toStringAsFixed(2)),
        _recipeResultRow("FINAL OLEFINS %", finalOle.toStringAsFixed(1)),
        _recipeResultRow("FINAL SULFUR (ppm)", finalS.toStringAsFixed(0)),
        _recipeResultRow("FINAL RVP", finalRvp.toStringAsFixed(2)),
        _recipeResultRow("TOTAL BATCH LEVEL", "${totalLevel.toStringAsFixed(1)} cm"),
      ],
    ),
  );

  Widget _recipeTable() => Table(
    border: TableBorder.all(color: Colors.black26),
    children: [
      TableRow(decoration: BoxDecoration(color: Colors.grey[300]), children: [_th("Tank"), _th("Prod"), _th("Level"), _th("Oct")]),
      ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
        children: [_td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
      )).toList()
    ],
  );

  Widget _th(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 9), textAlign: TextAlign.center));
  Widget _recipeResultRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.black87, fontSize: 10)), Text(v, style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))]);

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
    }
  }
}
