//
//  PlayerMaskViewLayout.swift
//  
//
//  Created by 成璐飞 on 2023/3/1.
//

import UIKit

// MARK: - 布局
extension PlayerMaskView {
    func configSubviews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.25)
        layoutTop()
        layoutCenter()
        layoutBottom()
    }
    
    func layoutTop() {
        addSubview(closeBtn)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pipBtn)
        pipBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fullScreenBtn)
        fullScreenBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lockScreenBtn)
        lockScreenBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            closeBtn.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor, constant: 20),
            pipBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 70),
            pipBtn.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            fullScreenBtn.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            fullScreenBtn.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor, constant: -15),
            lockScreenBtn.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            lockScreenBtn.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor, constant: -65)
        ])
    }
    
    func layoutCenter() {
        addSubview(centerBtn)
        centerBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(goforwardBtn)
        goforwardBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gobackwardBtn)
        gobackwardBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerBtn.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerBtn.heightAnchor.constraint(equalToConstant: 60),
            centerBtn.widthAnchor.constraint(equalToConstant: 50),
            loadingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingView.heightAnchor.constraint(equalToConstant: 50),
            loadingView.widthAnchor.constraint(equalToConstant: 50),
            goforwardBtn.centerYAnchor.constraint(equalTo: centerBtn.centerYAnchor),
            goforwardBtn.leftAnchor.constraint(equalTo: centerBtn.rightAnchor, constant: 40),
            goforwardBtn.heightAnchor.constraint(equalToConstant: 30),
            goforwardBtn.widthAnchor.constraint(equalToConstant: 30),
            gobackwardBtn.centerYAnchor.constraint(equalTo: centerBtn.centerYAnchor),
            gobackwardBtn.rightAnchor.constraint(equalTo: centerBtn.leftAnchor, constant: -40),
            gobackwardBtn.heightAnchor.constraint(equalToConstant: 30),
            gobackwardBtn.widthAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func layoutBottom() {
        addSubview(routePickerView)
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedBtn)
        speedBtn.translatesAutoresizingMaskIntoConstraints = false
        progressViewHeightConstraint = progressView.heightAnchor.constraint(equalToConstant: 5)
        addSubview(progressView)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftTimeLabel)
        leftTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightTimeLabel)
        rightTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            routePickerView.rightAnchor.constraint(equalTo: progressView.rightAnchor),
            routePickerView.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -20),
            speedBtn.centerYAnchor.constraint(equalTo: routePickerView.centerYAnchor),
            speedBtn.rightAnchor.constraint(equalTo: routePickerView.leftAnchor, constant: -25),
            progressView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -30),
            progressViewHeightConstraint,
            progressView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 5),
            progressView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor, constant: -5),
            leftTimeLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            leftTimeLabel.leftAnchor.constraint(equalTo: progressView.leftAnchor),
            rightTimeLabel.topAnchor.constraint(equalTo: leftTimeLabel.topAnchor),
            rightTimeLabel.rightAnchor.constraint(equalTo: progressView.rightAnchor)
        ])
    }
}
