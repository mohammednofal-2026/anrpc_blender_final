import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

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

  // متغيرات النتائج
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: Colors.blueGrey[900],
        title: Text("Gasoline Blending Calculator", style: TextStyle(fontSize: 14)),
        actions: [
          DropdownButton<String>(
            value: productGrade,
            underline: Container(),
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text("Grade $s "))).toList(),
            onChanged: (v) => setState(() => productGrade = v!),
          ),
          IconButton(icon: Icon(Icons.save_alt, color: Colors.green), onPressed: _showRecipeDialog),
        ],
      ),
      body: Column(
        children: [
          // 1. جدول المدخلات - مرن ويملأ المساحة
          Expanded(
            child: Container(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 10,
                    horizontalMargin: 5,
                    headingRowHeight: 35,
                    dataRowHeight: 35,
                    headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                    border: TableBorder.all(color: Colors.grey[800]!),
                    columns: ['Tank', 'Prod', 'Level', 'Oct', 'Sens', 'Den', 'Ar%', 'Ben%', 'Ole%', 'RVP', 'S%']
                        .map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))).toList(),
                    rows: rowsData.map((row) => DataRow(cells: [
                      _inputCell(row['tank']!, 50, true), _inputCell(row['prod']!, 65, true),
                      _inputCell(row['level']!, 45, false), _inputCell(row['oct']!, 35, false),
                      _inputCell(row['sens']!, 35, false), _inputCell(row['den']!, 55, false),
                      _inputCell(row['ar']!, 35, false), _inputCell(row['ben']!, 35, false),
                      _inputCell(row['ole']!, 35, false), _inputCell(row['rvp']!, 40, false),
                      _inputCell(row['s']!, 35, false),
                    ])).toList(),
                  ),
                ),
              ),
            ),
          ),
          // 2. لوحة النتائج النهائية - Dashboard (زي الصورة اللي بعتها)
          _buildFinalDashboard(),
        ],
      ),
    );
  }

  Widget _buildFinalDashboard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        border: Border(top: BorderSide(color: Colors.orangeAccent, width: 2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dashItem("TOTAL LEVEL", "${totalLevel.toStringAsFixed(1)} cm", Colors.white),
              _dashItem("ETHYL OCTANE", ethyl135.toStringAsFixed(2), _getSpecColor("OCT", ethyl135)),
              _dashItem("DENSITY", finalDen.toStringAsFixed(4), Colors.cyanAccent),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dashItem("AROMATICS%", "${finalAr.toStringAsFixed(1)}%", _getSpecColor("AR", finalAr)),
              _dashItem("BENZENE%", "${finalBen.toStringAsFixed(2)}%", _getSpecColor("BEN", finalBen)),
              _dashItem("RVP", "${finalRvp.toStringAsFixed(2)} Kg/cm²", _getSpecColor("RVP", finalRvp)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashItem(String label, String value, Color col) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: col, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Color _getSpecColor(String type, double val) {
    if (productGrade == "95") {
      if (type == "OCT") return val >= 95 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 33 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 0.9 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= 0.7 ? Colors.greenAccent : Colors.redAccent;
    } else {
      if (type == "OCT") return val >= 92 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 35 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 1.0 ? Colors.greenAccent : Colors.redAccent;
    }
    return Colors.white;
  }

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, 
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10, color: Colors.white),
      keyboardType: isTxt ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(border: InputBorder.none, isDense: true),
    )),
  );

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Gasoline Blending Recipe", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blue, fontSize: 11)),
              Divider(),
              _recipeTable(),
              Divider(),
              _recipeRow("FINAL ETHYL OCTANE:", ethyl135.toStringAsFixed(2)),
              _recipeRow("FINAL RVP:", finalRvp.toStringAsFixed(2)),
              _recipeRow("FINAL DENSITY:", finalDen.toStringAsFixed(4)),
            ],
          ),
        ),
      ),
      actions: [ElevatedButton(onPressed: _saveImg, child: Text("Save Report"))],
    ));
  }

  Widget _recipeTable() {
    return Table(
      border: TableBorder.all(color: Colors.black12),
      children: [
        TableRow(children: [_th("Tank"), _th("Prod"), _th("Level"), _th("Oct")]),
        ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
          children: [_td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
        )).toList()
      ],
    );
  }

  Widget _th(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 10), textAlign: TextAlign.center));
  Widget _recipeRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.black, fontSize: 10)), Text(v, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))]);

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
    }
  }
}
